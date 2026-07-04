import CoreData
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-552 — the DUT-525 recovery seam recovered on ANY thrown error, so a
/// TRANSIENT open failure (disk momentarily full, store still `-wal`-locked by a
/// terminating prior process, protected-data-unavailable pre-first-unlock,
/// generic POSIX/`NSFileProvider` I/O) silently moved the intact store aside and
/// launched the user into an empty app — permanent-looking data loss.
///
/// The fix: only reset immediately on a GENUINELY unrecoverable error (Core Data
/// migration domain / `SQLITE_CORRUPT`), and gate every other reset behind a
/// persisted consecutive-failed-open counter so a single transient failure
/// RETHROWS (the next launch retries the intact store) and only a store that
/// keeps failing `resetFailureThreshold` launches is reset. These pin that
/// behavior by injection.
@Suite("Transient open failure does not reset (DUT-552)")
struct TransientOpenFailureTests {

    /// A transient POSIX I/O error — the store is fine, the open just failed
    /// this once (locked, disk full, protected-data-unavailable).
    static func transientError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(EAGAIN), userInfo: nil)
    }

    /// A genuine on-disk corruption error (SQLite malformed database).
    static func corruptError() -> NSError {
        NSError(domain: NSSQLiteErrorDomain, code: 11, userInfo: nil)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "dut552.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - Transient path: rethrow, never reset, retry intact store next launch

    /// The core regression: a SINGLE transient open failure must NOT recover —
    /// it rethrows so the NEXT launch retries the INTACT store, and the data the
    /// intact store holds is still there when that retry succeeds.
    @Test func singleTransientFailureRethrowsWithoutResetting() throws {
        let defaults = freshDefaults()
        var recoverCalled = false

        #expect(throws: NSError.self) {
            _ = try RecipeStore.buildWithMigrationRecovery(
                defaults: defaults,
                build: { throw Self.transientError() },
                recover: { _ in
                    recoverCalled = true
                    return try RecipeStore.inMemoryContainer()
                }
            )
        }

        // The destructive reset NEVER ran on a lone transient failure.
        #expect(recoverCalled == false)
        // One failure recorded so a subsequent one can cross the threshold.
        #expect(defaults.integer(forKey: RecipeStore.consecutiveFailedOpensKey) == 1)
    }

    /// After a transient failure rethrows, the NEXT launch retries the intact
    /// store; when it opens, the seam returns it WITHOUT recovering and the
    /// pre-existing data is intact. This models the real self-healing sequence.
    @Test func nextLaunchAfterTransientSeesIntactData() async throws {
        let defaults = freshDefaults()

        // Seed a store with real user data (a saved recipe pin + a cached row).
        let intact = try RecipeStore.inMemoryContainer()
        let seedStore = RecipeStore(modelContainer: intact)
        try await seedStore.cache(listItem: makeListItem(id: 7, title: "Keeper"))

        // Launch 1: the open throws transiently. It rethrows, does not reset.
        #expect(throws: NSError.self) {
            _ = try RecipeStore.buildWithMigrationRecovery(
                defaults: defaults,
                build: { throw Self.transientError() },
                recover: { _ in
                    Issue.record("must not recover on a lone transient failure")
                    return intact
                }
            )
        }

        // Launch 2: the transient condition cleared; the INTACT store opens.
        let result = try RecipeStore.buildWithMigrationRecovery(
            defaults: defaults,
            build: {
                RecipeStore.ContainerBuildResult(
                    container: intact,
                    usedCloudKitFallback: false
                )
            },
            recover: { _ in
                Issue.record("must not recover once the intact store opens")
                return intact
            }
        )

        #expect(result.recoveredFromMigrationFailure == false)
        // The seeded data survived — nothing was wiped.
        let reopened = RecipeStore(modelContainer: result.container)
        let rows = try await reopened.listItems(forIDs: [7])
        #expect(rows.count == 1)
        #expect(rows.first?.title == "Keeper")
        // A successful open clears the failed-open counter.
        #expect(defaults.object(forKey: RecipeStore.consecutiveFailedOpensKey) == nil)
    }

    /// The counter path: a store that keeps failing transiently for
    /// `resetFailureThreshold` CONSECUTIVE launches is reset as a last resort
    /// (a truly stuck store shouldn't crash-loop forever), but not before.
    @Test func repeatedTransientFailuresEventuallyReset() throws {
        let defaults = freshDefaults()
        var recoverCount = 0

        func attempt() throws -> RecipeStore.ContainerBuildResult {
            try RecipeStore.buildWithMigrationRecovery(
                defaults: defaults,
                build: { throw Self.transientError() },
                recover: { _ in
                    recoverCount += 1
                    return try RecipeStore.inMemoryContainer()
                }
            )
        }

        // Launch 1 (below threshold): rethrows, no reset.
        #expect(throws: NSError.self) { _ = try attempt() }
        #expect(recoverCount == 0)

        // Launch 2 (reaches resetFailureThreshold == 2): resets as last resort.
        let result = try attempt()
        #expect(recoverCount == 1)
        #expect(result.recoveredFromMigrationFailure == true)
        // Counter cleared after the recovery.
        #expect(defaults.object(forKey: RecipeStore.consecutiveFailedOpensKey) == nil)
    }

    // MARK: - Corruption path: still self-heals on the FIRST failure (DUT-525)

    /// A genuinely corrupt store must STILL recover to a fresh store on the
    /// first failure — DUT-525's contract, un-weakened. The counter gate applies
    /// only to assumed-transient errors.
    @Test func genuineCorruptionRecoversOnFirstFailure() throws {
        let defaults = freshDefaults()
        let fresh = try RecipeStore.inMemoryContainer()
        var recoverCalled = false

        let result = try RecipeStore.buildWithMigrationRecovery(
            defaults: defaults,
            build: { throw Self.corruptError() },
            recover: { _ in
                recoverCalled = true
                return fresh
            }
        )

        #expect(recoverCalled)
        #expect(result.recoveredFromMigrationFailure == true)
        #expect(result.container === fresh)
    }

    /// Error classification unit-check: SQLite corruption + Core Data migration
    /// codes are unrecoverable; a transient POSIX I/O error is not — even when
    /// wrapped as an `NSUnderlyingError`, matching how SwiftData nests causes.
    @Test func errorClassification() {
        #expect(RecipeStore.isUnrecoverableStoreError(Self.corruptError()))
        #expect(
            RecipeStore.isUnrecoverableStoreError(
                NSError(domain: NSCocoaErrorDomain, code: 134_110, userInfo: nil)
            )
        )
        #expect(RecipeStore.isUnrecoverableStoreError(Self.transientError()) == false)

        // A corruption error wrapped inside a transient-looking outer error is
        // still classified unrecoverable via the underlying-error walk.
        let wrapped = NSError(
            domain: NSCocoaErrorDomain,
            code: 256,
            userInfo: [NSUnderlyingErrorKey: Self.corruptError()]
        )
        #expect(RecipeStore.isUnrecoverableStoreError(wrapped))
    }
}

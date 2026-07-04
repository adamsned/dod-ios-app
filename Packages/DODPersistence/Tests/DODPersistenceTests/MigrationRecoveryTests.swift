import CoreData
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-525 — a failed opt-out SwiftData migration on the launch path used to
/// rethrow straight into `AppDependencies.init`'s `fatalError`, an
/// un-recoverable synchronous launch crash-loop with no user escape. The fix
/// wraps the container open in `buildWithMigrationRecovery(defaults:build:recover:)`:
/// on a genuine migration/corruption error it moves the corrupt store aside and
/// opens a FRESH one, flagging `recoveredFromMigrationFailure`. These pin that
/// seam by injection (a real corrupt on-disk migration can't be forced
/// hermetically), so a failed migration RECOVERS to a working store instead of
/// trapping.
///
/// DUT-552 — the seam must ONLY reset on a genuinely unrecoverable error, and
/// gate any other (assumed-transient) reset behind a consecutive-failed-open
/// counter, so a single transient open failure never wipes real user data. The
/// `TransientDoesNotResetTests` suite below pins that regression fix; these
/// DUT-525 tests use a genuine corruption error so the recovery path still runs
/// on the first failure.
@Suite("Migration recovery (DUT-525)")
struct MigrationRecoveryTests {

    /// A genuinely unrecoverable Core Data migration error — classified as
    /// unrecoverable, so recovery fires on the FIRST failure (DUT-552).
    static func corruptionError() -> NSError {
        NSError(
            domain: NSCocoaErrorDomain,
            code: 134_100,  // NSPersistentStoreIncompatibleVersionHashError
            userInfo: nil
        )
    }

    private func freshDefaults() -> UserDefaults {
        let name = "dut525.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func failedMigrationRecoversToAFreshStore() throws {
        let freshContainer = try RecipeStore.inMemoryContainer()
        var recoverCalled = false

        let result = try RecipeStore.buildWithMigrationRecovery(
            defaults: freshDefaults(),
            build: { throw Self.corruptionError() },
            recover: { _ in
                recoverCalled = true
                return freshContainer
            }
        )

        #expect(recoverCalled)
        #expect(result.recoveredFromMigrationFailure == true)
        #expect(result.container === freshContainer)
        // Recovery is not a CloudKit fallback — that flag stays false.
        #expect(result.usedCloudKitFallback == false)
    }

    @Test func recoveredStoreIsUsableForInsertAndRead() throws {
        let freshContainer = try RecipeStore.inMemoryContainer()

        let result = try RecipeStore.buildWithMigrationRecovery(
            defaults: freshDefaults(),
            build: { throw Self.corruptionError() },
            recover: { _ in freshContainer }
        )

        // The user lands in a working-but-empty app: prove the recovered
        // container round-trips a basic insert/read.
        let context = ModelContext(result.container)
        context.insert(
            CachedRecipe(
                id: 1,
                slug: "s",
                title: "Recovered",
                excerptText: "e",
                canonicalURLString: "https://example.com/1",
                publishedAt: .now
            )
        )
        try context.save()
        let rows = try context.fetch(
            FetchDescriptor<CachedRecipe>(predicate: #Predicate { $0.id == 1 })
        )
        #expect(rows.count == 1)
    }

    @Test func successfulOpenNeverRecovers() throws {
        let primaryContainer = try RecipeStore.inMemoryContainer()

        let result = try RecipeStore.buildWithMigrationRecovery(
            defaults: freshDefaults(),
            build: {
                RecipeStore.ContainerBuildResult(
                    container: primaryContainer,
                    usedCloudKitFallback: false
                )
            },
            recover: { _ in
                Issue.record("recovery must not run when the primary open succeeds")
                return primaryContainer
            }
        )

        #expect(result.recoveredFromMigrationFailure == false)
        #expect(result.container === primaryContainer)
    }

    /// If even the fresh-store recovery throws, the error propagates — the
    /// vanishingly-rare last resort that still reaches `fatalError`. This proves
    /// we only trap when there is genuinely nothing left to open.
    @Test func recoveryFailurePropagates() throws {
        struct RecoveryAlsoFailed: Error {}

        #expect(throws: RecoveryAlsoFailed.self) {
            _ = try RecipeStore.buildWithMigrationRecovery(
                defaults: freshDefaults(),
                build: { throw Self.corruptionError() },
                recover: { _ in throw RecoveryAlsoFailed() }
            )
        }
    }
}

import CoreData
import Foundation
import SwiftData

// MARK: - DUT-525 / DUT-552: launch-path migration recovery
//
// A failed opt-out SwiftData migration (a future V-chain regression or on-disk
// corruption on a POPULATED store) threw SYNCHRONOUSLY in
// `AppDependencies.init()`, before the first frame — straight into a
// `fatalError`, which made it an un-recoverable launch crash-loop with no user
// escape. This seam moves the corrupt store aside and opens a FRESH one so the
// user lands in a working-but-empty app instead of a brick (DUT-525).
//
// DUT-552 — the DUT-525 seam recovered on ANY thrown error, so a TRANSIENT open
// failure (disk momentarily full, store still `-wal`-locked by a terminating
// prior process, protected-data-unavailable pre-first-unlock, generic I/O)
// silently wiped the user's entire local cache into a fresh empty app. The seam
// now (1) only resets immediately on GENUINELY unrecoverable errors (Core Data
// migration domain, `SQLITE_CORRUPT`/malformed store), and (2) gates the
// destructive reset for every other (assumed-transient) error behind a persisted
// consecutive-failed-open counter, so a single transient failure RETHROWS (the
// next launch retries the intact store) and only a store that keeps failing
// `resetFailureThreshold` launches in a row is reset as a last resort.
//
// Extracted from RecipeStore+Containers.swift to keep both files under the
// SwiftLint 400-line file_length cap.

extension RecipeStore {

    /// `UserDefaults` key for the DUT-552 consecutive-failed-open counter. A
    /// successful open clears it; each failed open increments it. The destructive
    /// reset only fires once it reaches ``resetFailureThreshold``.
    static let consecutiveFailedOpensKey = "dod.persistence.consecutiveFailedOpensV1"

    /// DUT-552 — a transient open failure must NOT wipe data on its first
    /// occurrence. Only after this many consecutive failed opens of the same
    /// store do we treat an otherwise-transient error as unrecoverable and reset.
    /// `2` means: fail once (rethrow, retry intact store next launch); fail a
    /// second consecutive time, reset.
    static let resetFailureThreshold = 2

    /// The launch-path recovery seam, testable by injection. Attempts `build`.
    /// On success the failed-open counter is cleared and the result returned.
    ///
    /// On a thrown error (DUT-552): the consecutive-failed-open counter is
    /// incremented, then we recover (production: move the store aside + open
    /// fresh via `recover`) ONLY when the error is genuinely unrecoverable
    /// (``isUnrecoverableStoreError(_:)`` — Core Data migration / corruption) OR
    /// the store has now failed to open ``resetFailureThreshold`` consecutive
    /// launches. For any other (assumed-transient) error below the threshold we
    /// RETHROW with the counter persisted, so the NEXT launch retries the INTACT
    /// store rather than wiping it. On recovery, the counter is cleared and
    /// `recoveredFromMigrationFailure` flagged so the host can log/telemeter it.
    ///
    /// Takes closures (not a store URL) so the L1 suite can prove the happy
    /// path, the transient-rethrow path, and the corruption-recovery path against
    /// in-memory containers without touching the shared on-disk `default.store`.
    static func buildWithMigrationRecovery(
        defaults: UserDefaults,
        build: () throws -> ContainerBuildResult,
        recover: (_ failure: Error) throws -> ModelContainer
    ) throws -> ContainerBuildResult {
        do {
            let result = try build()
            defaults.removeObject(forKey: consecutiveFailedOpensKey)
            return result
        } catch {
            let failures = defaults.integer(forKey: consecutiveFailedOpensKey) + 1
            defaults.set(failures, forKey: consecutiveFailedOpensKey)
            let unrecoverable = isUnrecoverableStoreError(error)
            guard unrecoverable || failures >= resetFailureThreshold else {
                // Assumed-transient, below the reset threshold: leave the store
                // intact and rethrow so the next launch retries it (pre-DUT-525
                // non-destructive, self-healing behavior).
                throw error
            }
            let fresh = try recover(error)
            defaults.removeObject(forKey: consecutiveFailedOpensKey)
            return ContainerBuildResult(
                container: fresh,
                usedCloudKitFallback: false,
                recoveredFromMigrationFailure: true
            )
        }
    }

    /// DUT-552 — classify a container-open error as a GENUINELY unrecoverable
    /// migration/corruption failure (reset immediately) vs. an assumed-transient
    /// one (disk full, store locked, protected-data-unavailable, generic I/O —
    /// rethrow and retry the intact store next launch).
    ///
    /// Unrecoverable when the thrown `NSError` (or any error in its
    /// `underlyingErrors` chain) is:
    /// - a Core Data migration error (`NSCocoaErrorDomain`
    ///   `NSPersistentStoreIncompatibleVersionHashError` /
    ///   `NSMigrationError`…`NSMigrationManagerSourceStoreError` range,
    ///   `NSPersistentStoreOpenError` for a malformed store), or
    /// - a SQLite `SQLITE_CORRUPT` (11) / `SQLITE_NOTADB` (26) result code.
    static func isUnrecoverableStoreError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if isUnrecoverableNSError(nsError) { return true }
        // SwiftData/Core Data wrap the real cause; walk the underlying chain.
        var nested = nsError.underlyingErrors
        if let legacy = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            nested.append(legacy)
        }
        return nested.contains { isUnrecoverableStoreError($0) }
    }

    private static func isUnrecoverableNSError(_ nsError: NSError) -> Bool {
        switch nsError.domain {
        case NSCocoaErrorDomain:
            return unrecoverableCocoaCodes.contains(nsError.code)
        case NSSQLiteErrorDomain:
            // The `code` here is the raw SQLite result code. 11 == SQLITE_CORRUPT
            // (malformed database), 26 == SQLITE_NOTADB (file is not a database).
            return nsError.code == 11 || nsError.code == 26
        default:
            return false
        }
    }

    /// Core Data (`NSCocoaErrorDomain`) codes that mean the on-disk store cannot
    /// be migrated/opened as-is — a genuine, unrecoverable migration/corruption
    /// failure that must self-heal to a fresh store rather than crash-loop.
    private static let unrecoverableCocoaCodes: Set<Int> = [
        134_100,  // NSPersistentStoreIncompatibleVersionHashError
        134_110,  // NSMigrationError
        134_130,  // NSMigrationMissingSourceModelError
        134_140,  // NSMigrationMissingMappingModelError
        134_170,  // NSMigrationManagerSourceStoreError
        134_180,  // NSMigrationManagerDestinationStoreError
        134_190,  // NSEntityMigrationPolicyError
        // NSPersistentStoreOpenError (malformed / unopenable store). Included so
        // a store that Core Data itself reports as un-openable self-heals.
        134_080,
    ]

    /// Production launch entry point. Wraps ``productionContainer(defaults:)`` in
    /// ``buildWithMigrationRecovery(defaults:build:recover:)`` so a failed
    /// migration on a populated store is survivable while a transient open
    /// failure is NOT destructive (DUT-552). Replaces the direct
    /// `productionContainer` call that fed `AppDependencies.init`'s `fatalError`.
    public static func productionContainerRecoveringFromMigrationFailure(
        defaults: UserDefaults
    ) throws -> ContainerBuildResult {
        try buildWithMigrationRecovery(
            defaults: defaults,
            build: { try productionContainer(defaults: defaults) },
            recover: { _ in
                // A CloudKit-mirrored open can't itself be the migration failure
                // (its own fallback handles that), so recovery always opens the
                // plain local layout after moving the corrupt store aside.
                resetOnDiskStores()
                return try ModelContainer(
                    for: Schema(SchemaV6.models),
                    migrationPlan: MigrationPlan.self,
                    configurations: localCacheConfiguration(inMemory: false),
                    syncedSavedConfiguration(inMemory: false, cloudKit: false)
                )
            }
        )
    }

    /// Move any on-disk SwiftData store files aside so the next open starts from
    /// a clean slate. Renames rather than deletes, so a corrupt store is
    /// preserved for post-mortem rather than destroyed. Best effort: a rename
    /// failure is swallowed so recovery still attempts the fresh open.
    static func resetOnDiskStores() {
        let fileManager = FileManager.default
        guard
            let supportDirectory = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else { return }
        // SwiftData writes `default.store` (+ `-wal` / `-shm` sidecars) for the
        // unnamed local config and `SyncedSaved.store` for the named one.
        let stems = ["default.store", "SyncedSaved.store"]
        let suffixes = ["", "-wal", "-shm"]
        let stamp = Int(Date().timeIntervalSince1970)
        for stem in stems {
            for suffix in suffixes {
                let source = supportDirectory.appendingPathComponent(stem + suffix)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                let destination = supportDirectory.appendingPathComponent(
                    "\(stem).corrupt-\(stamp)\(suffix)"
                )
                try? fileManager.moveItem(at: source, to: destination)
            }
        }
    }
}

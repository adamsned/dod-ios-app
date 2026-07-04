import Foundation
import SwiftData

// MARK: - DUT-525: launch-path migration recovery
//
// A failed opt-out SwiftData migration (a future V-chain regression or on-disk
// corruption on a POPULATED store) threw SYNCHRONOUSLY in
// `AppDependencies.init()`, before the first frame — straight into a
// `fatalError`, which made it an un-recoverable launch crash-loop with no user
// escape. This seam moves the corrupt store aside and opens a FRESH one so the
// user lands in a working-but-empty app instead of a brick.
//
// Extracted from RecipeStore+Containers.swift to keep both files under the
// SwiftLint 400-line file_length cap.

extension RecipeStore {

    /// The launch-path recovery seam, testable by injection. Attempts `build`;
    /// on **any thrown error** invokes `recover` (production: move the corrupt
    /// store aside + open fresh) and flags `recoveredFromMigrationFailure`, so
    /// the user gets a working-but-empty app rather than a bricked launch. Only
    /// if `recover` ALSO throws does the error propagate — nothing left to do.
    ///
    /// Takes closures (not a store URL) so the L1 suite can prove both the happy
    /// path and the recovery path against in-memory containers without touching
    /// the shared on-disk `default.store`.
    static func buildWithMigrationRecovery(
        build: () throws -> ContainerBuildResult,
        recover: (_ failure: Error) throws -> ModelContainer
    ) throws -> ContainerBuildResult {
        do {
            return try build()
        } catch {
            let fresh = try recover(error)
            return ContainerBuildResult(
                container: fresh,
                usedCloudKitFallback: false,
                recoveredFromMigrationFailure: true
            )
        }
    }

    /// Production launch entry point. Wraps ``productionContainer(defaults:)`` in
    /// ``buildWithMigrationRecovery(build:recover:)`` so a failed migration on a
    /// populated store is survivable. Replaces the direct `productionContainer`
    /// call that fed `AppDependencies.init`'s `fatalError`.
    public static func productionContainerRecoveringFromMigrationFailure(
        defaults: UserDefaults
    ) throws -> ContainerBuildResult {
        try buildWithMigrationRecovery(
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

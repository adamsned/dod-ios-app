import Foundation
import Testing

@testable import DODPersistence

/// DUT-586 (High) — the DUT-525/DUT-552 recovery seam moved BOTH `default.store`
/// AND `SyncedSaved.store` aside on any recovery. For a user NOT opted into
/// CloudKit, `SyncedSaved.store` is local-only with no remote copy, so sweeping
/// it destroyed the SOLE copy of their entire Saved list — permanent data loss,
/// since nothing ever re-imports the `.corrupt-<stamp>` file for an opted-out
/// user. The fix scopes the reset: `default.store` (the cache that actually
/// fails migration) always resets, but `SyncedSaved.store` is only swept aside
/// when the CloudKit mirror is active (opt-in ON) so a re-import can re-hydrate
/// it. These pin the sweep-scope contract against a temp directory (the
/// production seam resolves the real Application Support directory).
@Suite("Migration recovery preserves opted-out Saved list (DUT-586)")
struct MigrationRecoverySavedListTests {

    /// A temp working directory seeded with sentinel store files, cleaned up on
    /// deinit so no `.corrupt-*` artifacts linger.
    private final class TempStoreDir {
        let url: URL
        init() throws {
            url = FileManager.default.temporaryDirectory
                .appendingPathComponent("dut586.\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
        deinit { try? FileManager.default.removeItem(at: url) }

        func seed(_ name: String, _ contents: String = "x") throws {
            try contents.data(using: .utf8)?.write(
                to: url.appendingPathComponent(name)
            )
        }

        func exists(_ name: String) -> Bool {
            FileManager.default.fileExists(
                atPath: url.appendingPathComponent(name).path
            )
        }

        /// True when any file matching `<stem>.corrupt-*` was left behind.
        func hasCorruptAside(stemPrefix: String) throws -> Bool {
            let entries = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return entries.contains { $0.hasPrefix("\(stemPrefix).store.corrupt-") }
        }
    }

    private func freshDefaults() -> UserDefaults {
        let name = "dut586.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - Opted-OUT: the local-only Saved store SURVIVES the reset

    /// The core regression: an opted-out user's `SyncedSaved.store` must stay in
    /// place while `default.store` is swept aside, so a corrupt cache never wipes
    /// their Saved list.
    @Test func optedOutSavedStoreSurvivesResetOfDefaultStore() throws {
        let dir = try TempStoreDir()
        try dir.seed("default.store")
        try dir.seed("default.store-wal")
        try dir.seed("SyncedSaved.store")
        try dir.seed("SyncedSaved.store-wal")

        // Opt-in OFF ⇒ do NOT sweep the synced store.
        RecipeStore.resetStores(in: dir.url, includingSyncedStore: false)

        // The failing cache store was swept aside (DUT-552 `.corrupt-<stamp>`).
        #expect(dir.exists("default.store") == false)
        #expect(try dir.hasCorruptAside(stemPrefix: "default"))
        // The Saved list is intact and NOT renamed aside — no data loss.
        #expect(dir.exists("SyncedSaved.store"))
        #expect(dir.exists("SyncedSaved.store-wal"))
        #expect(try dir.hasCorruptAside(stemPrefix: "SyncedSaved") == false)
    }

    /// The opt-in state that recovery reads is the persisted CloudKit-sync flag.
    /// An opted-out `UserDefaults` reads `false`, which is what gates the synced
    /// store out of the sweep.
    @Test func optOutFlagKeepsSyncedStoreOutOfSweep() throws {
        let defaults = freshDefaults()
        #expect(RecipeStore.cloudKitSyncOptIn(in: defaults) == false)

        let dir = try TempStoreDir()
        try dir.seed("default.store")
        try dir.seed("SyncedSaved.store")

        RecipeStore.resetStores(
            in: dir.url,
            includingSyncedStore: RecipeStore.cloudKitSyncOptIn(in: defaults)
        )

        #expect(dir.exists("default.store") == false)
        #expect(dir.exists("SyncedSaved.store"))
    }

    // MARK: - Opted-IN: unchanged — both stores are swept (CloudKit re-hydrates)

    /// An opted-in user has a CloudKit mirror, so sweeping `SyncedSaved.store`
    /// aside is safe (a re-import re-hydrates it). Behavior for that user is
    /// unchanged — both stores move aside.
    @Test func optedInSweepsBothStores() throws {
        let dir = try TempStoreDir()
        try dir.seed("default.store")
        try dir.seed("SyncedSaved.store")
        try dir.seed("SyncedSaved.store-shm")

        // Opt-in ON ⇒ sweep both (a CloudKit re-import can restore the synced one).
        RecipeStore.resetStores(in: dir.url, includingSyncedStore: true)

        #expect(dir.exists("default.store") == false)
        #expect(dir.exists("SyncedSaved.store") == false)
        #expect(dir.exists("SyncedSaved.store-shm") == false)
        #expect(try dir.hasCorruptAside(stemPrefix: "default"))
        #expect(try dir.hasCorruptAside(stemPrefix: "SyncedSaved"))
    }

    /// The opt-in flag set to `true` drives the synced store INTO the sweep,
    /// mirroring how `productionContainerRecoveringFromMigrationFailure` reads it.
    @Test func optInFlagSweepsSyncedStore() throws {
        let defaults = freshDefaults()
        defaults.set(true, forKey: RecipeStore.cloudKitSyncOptInKey)
        #expect(RecipeStore.cloudKitSyncOptIn(in: defaults))

        let dir = try TempStoreDir()
        try dir.seed("default.store")
        try dir.seed("SyncedSaved.store")

        RecipeStore.resetStores(
            in: dir.url,
            includingSyncedStore: RecipeStore.cloudKitSyncOptIn(in: defaults)
        )

        #expect(dir.exists("default.store") == false)
        #expect(dir.exists("SyncedSaved.store") == false)
    }
}

import Foundation
import Testing

@testable import DODPersistence

/// DUT-733 — opt-in alone is not proof the CloudKit mirror is live. An
/// opted-in user whose CloudKit is unavailable runs on a LOCAL-ONLY fallback
/// `SyncedSaved` store; sweeping it on the opt-in flag alone would destroy
/// the sole copy of their Saved list. The fix requires BOTH opt-in AND a
/// confirmed import (`backfillDidComplete`) before sweeping the store.
///
/// `shouldSweepSyncedStore(defaults:)` is the extracted gate, tested here
/// by injecting a fresh isolated `UserDefaults` suite for each case.
@Suite("Sweep-gate: SyncedSaved swept only when mirror confirmed (DUT-733)")
struct MigrationRecoverySweepGateTests {

    private func freshDefaults() -> UserDefaults {
        let name = "dut733.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Opted-in AND backfill confirmed: the CloudKit mirror is live and a
    /// re-import can re-hydrate the store — sweep is safe.
    @Test func optedInAndBackfillConfirmedAllowsSweep() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: RecipeStore.cloudKitSyncOptInKey)
        defaults.set(true, forKey: RecipeStore.didBackfillSyncedSavedKey)
        #expect(RecipeStore.shouldSweepSyncedStore(defaults: defaults) == true)
    }

    /// Opted-in but backfill NOT yet confirmed: the mirror may be unavailable
    /// (no iCloud account, schema not deployed) so the store could be local-only.
    /// Must NOT sweep — the flag alone does not prove a remote copy exists.
    @Test func optedInWithoutBackfillBlocksSweep() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: RecipeStore.cloudKitSyncOptInKey)
        // didBackfillSyncedSavedKey deliberately absent (defaults to false)
        #expect(RecipeStore.shouldSweepSyncedStore(defaults: defaults) == false)
    }

    /// Opted-OUT: `SyncedSaved` is local-only with no remote copy. Sweep must
    /// be blocked regardless of any other flag state.
    @Test func optedOutBlocksSweep() {
        let defaults = freshDefaults()
        // Neither flag set — clean slate, as on a fresh install or after opt-out
        #expect(RecipeStore.shouldSweepSyncedStore(defaults: defaults) == false)
    }
}

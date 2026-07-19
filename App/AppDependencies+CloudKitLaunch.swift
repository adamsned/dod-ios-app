import DODPersistence
import DODSupport
import Foundation

// DUT-78: the crash-loop self-heal launch wiring, extracted from
// `AppDependencies.swift` to keep that file under the SwiftLint
// `file_length` cap.
//
// Root cause this closes (see `CloudKitAvailability.swift` /
// `LaunchHealthTracker.swift` in DODPersistence for the full writeup):
// enabling iCloud Sync opens the `SyncedSaved` store with `.private(...)`,
// which kicks off Core Data's ASYNCHRONOUS CloudKit mirroring setup. When the
// account can't back it (signed out, Production schema not provisioned for
// that account, an outage), that async setup traps — AFTER the synchronous
// `ModelContainer(...)` open already "succeeded" — so the existing
// DOD-CRASH-1 do/catch never sees it. DUT-630 already closed the Simulator
// instance of this trap; this closes the real-device instance with two
// layered guards: a pre-open account-status probe (cached from the previous
// launch, since the probe is async and the container build is not) and a
// self-heal escape hatch (force local + clear the opt-in flag after N
// consecutive crash-looping launches).
extension AppDependencies {

    /// Build the production container with both DUT-78 guards wired in, and
    /// perform the one load-bearing side effect that must happen exactly
    /// where the guard decided it: if the self-heal escape hatch tripped this
    /// launch, force-clear the opt-in flag so the NEXT launch opens local
    /// cleanly (no probe, no `.private` attempt) without re-tripping the
    /// heal — the user re-enables sync from Settings once iCloud is fixed.
    static func buildProductionContainer(
        defaults: UserDefaults,
        launchHealth: LaunchHealthTracker
    ) throws -> RecipeStore.ContainerBuildResult {
        let result = try RecipeStore.productionContainerRecoveringFromMigrationFailure(
            defaults: defaults,
            accountStatus: CloudKitAvailability.cachedAccountStatus(in: defaults),
            launchHealth: launchHealth
        )
        if result.didSelfHeal {
            defaults.set(false, forKey: RecipeStore.cloudKitSyncOptInKey)
        }
        return result
    }

    /// DUT-78: if the self-heal escape hatch tripped this launch, surface it
    /// once for the device log (the opt-in flag was already force-cleared in
    /// `init`). Called once from `bootstrap()`.
    func logSelfHealIfNeeded() {
        guard didSelfHeal else { return }
        cloudKitDiagnostics.markContainerOpenFailed()
        DODLog.app.error(
            """
            CloudKit sync self-healed (DUT-78): the app had crash-looped, so \
            sync was force-disabled and a local-only store opened. Re-enable \
            from Settings once iCloud is signed in / the schema is deployed.
            """
        )
    }

    /// DUT-78: a previously-CloudKit-backed store is now TAINTED — Core Data
    /// stamped it for mirroring, so even a `.none` reopen can re-trigger the
    /// async setup. Log so a device follow-up can decide whether a full store
    /// rebuild is warranted. Called from the existing `usedCloudKitFallback`
    /// branch in `bootstrap()`.
    func logTaintedStoreIfNeeded() {
        guard RecipeStore.cloudKitStoreEverOpened(in: .standard) else { return }
        DODLog.app.error(
            "DUT-78: synced store likely tainted (was CloudKit-backed); a `.none` reopen can still re-trigger mirroring."
        )
    }
}

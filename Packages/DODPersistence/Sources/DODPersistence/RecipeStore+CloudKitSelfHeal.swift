import DODDomain
import Foundation
import SwiftData

// MARK: - DUT-78 CloudKit crash-loop self-heal
//
// Extracted from `RecipeStore+Containers.swift` to keep that file under the
// SwiftLint 400-line cap after the DUT-78 / T-791 hardening added the pre-open
// account-status guard + the self-heal escape hatch on top of the existing
// DUT-6 / DOD-CRASH-1 fallback. No behavior change relative to where this code
// first landed — it is still an extension on `RecipeStore`.

extension RecipeStore {

    /// `UserDefaults` key recording that the `SyncedSaved` store has at some
    /// point been opened CloudKit-backed (`.private(...)`) on this install
    /// (DUT-78). Set the first time we successfully *choose* the CloudKit
    /// configuration; read on later launches to detect a **tainted store** —
    /// once Core Data has stamped a store for CloudKit mirroring, reopening it
    /// as `.none` can still re-trigger mirroring and re-hit the async trap, so
    /// a previously-CloudKit store that we now want to open local is recorded
    /// here for a device follow-up to decide whether a full store rebuild is
    /// warranted. Versioned (`V1`) for clean future migration.
    public static let cloudKitStoreEverOpenedKey = "dod.cloudkit.storeEverOpenedV1"

    /// Whether this install has ever opened the synced store CloudKit-backed
    /// (DUT-78). `true` here while we are opening local (the fallback / heal
    /// paths) means the on-disk store is **tainted**: Core Data already stamped
    /// it for CloudKit mirroring, so reopening as `.none` can still re-trigger
    /// mirroring. The host logs this on the fallback path so a device follow-up
    /// can decide whether a full store rebuild is warranted. `public` so the
    /// App composition root (a separate module) can read it.
    public static func cloudKitStoreEverOpened(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: cloudKitStoreEverOpenedKey)
    }

    /// The DUT-78-hardened production-container build. Combines the original
    /// DUT-6 opt-in branch + DOD-CRASH-1 synchronous catch with two new
    /// guards that close the async-mirroring-trap crash-loop:
    ///
    /// 1. **Pre-open account-status guard.** When `accountStatus` is provided
    ///    (the host probes `CKContainer.accountStatus()` before this call) and
    ///    `CloudKitAvailability.shouldAttemptCloudKit(given:)` is `false`, we
    ///    open a plain local container instead of `.private(...)` — dodging the
    ///    async `com.apple.coredata.cloudkit.queue` trap entirely rather than
    ///    trying (and failing) to catch it. `nil` preserves the legacy
    ///    "attempt CloudKit on opt-in" behavior for callers that don't probe.
    /// 2. **Self-heal escape hatch.** When `launchHealth?.shouldSelfHeal` is
    ///    `true` (this install has crash-looped
    ///    ``LaunchHealthTracker/unhealthyLaunchLimit`` times), force a local
    ///    open and flag ``ContainerBuildResult/didSelfHeal`` so the host can
    ///    force-clear the opt-in flag — the last-resort recovery for a brand
    ///    new trap that neither guard above anticipated.
    ///
    /// On the local-open path for a previously-CloudKit (tainted) store we
    /// still open `.none`; SwiftData reuses the same on-disk store file, and
    /// the host records the taint via ``cloudKitStoreEverOpenedKey`` so a
    /// device follow-up can decide whether a full store rebuild is warranted.
    /// `inMemory` is the same test-only seam as the legacy entry point.
    public static func productionContainer(
        defaults: UserDefaults,
        accountStatus: CloudKitAvailability.AccountStatus?,
        launchHealth: LaunchHealthTracker?,
        inMemory: Bool = false
    ) throws -> ContainerBuildResult {
        let schema = Schema(SchemaV5.models)
        // DUT-35: the six cache models are local-only; ONLY `SyncedSavedRecipe`
        // is a CloudKit-mirror candidate. Both stores live in the same
        // container, so the `@ModelActor`'s single `ModelContext` reaches both.
        let local = localCacheConfiguration(inMemory: inMemory)
        let buildLocal: () throws -> ModelContainer = {
            try ModelContainer(
                for: schema,
                migrationPlan: inMemory ? nil : MigrationPlan.self,
                configurations: local,
                syncedSavedConfiguration(inMemory: inMemory, cloudKit: false)
            )
        }
        guard cloudKitSyncOptIn(in: defaults) else {
            // Opt-out: both stores local. A failure here is a real
            // migration error and must propagate.
            return ContainerBuildResult(
                container: try buildLocal(),
                usedCloudKitFallback: false
            )
        }
        // DUT-78 self-heal escape hatch: after repeated crash-looping
        // launches, open local regardless of the account probe so the app
        // becomes launchable and the user can reach Settings. Flagged so the
        // host force-clears the opt-in flag.
        if launchHealth?.shouldSelfHeal == true {
            return ContainerBuildResult(
                container: try buildLocal(),
                usedCloudKitFallback: true,
                didSelfHeal: true
            )
        }
        // DUT-78 pre-open account-status guard: if the host probed the account
        // and it isn't `.available`, do NOT open `.private(...)` — that is the
        // open that risks the async mirroring trap. Fall back to local now.
        let attemptCloudKit =
            accountStatus.map(CloudKitAvailability.shouldAttemptCloudKit(given:)) ?? true
        if !attemptCloudKit {
            return ContainerBuildResult(
                container: try buildLocal(),
                usedCloudKitFallback: true
            )
        }
        // Opt-in + (account available OR not probed): mark the store as
        // CloudKit-touched (DUT-78 taint tracking) and mirror ONLY the synced
        // store to the CloudKit private DB, falling back to an all-local
        // layout if the *synchronous* `.private` open throws (DOD-CRASH-1).
        if !inMemory {
            defaults.set(true, forKey: cloudKitStoreEverOpenedKey)
        }
        return try buildCloudKitWithFallback(
            cloudKitBuild: {
                try ModelContainer(
                    for: schema,
                    migrationPlan: inMemory ? nil : MigrationPlan.self,
                    configurations: local,
                    syncedSavedConfiguration(inMemory: inMemory, cloudKit: true)
                )
            },
            localBuild: buildLocal
        )
    }
}

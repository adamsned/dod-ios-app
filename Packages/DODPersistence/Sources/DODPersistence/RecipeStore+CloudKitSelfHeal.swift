import DODDomain
import Foundation
import SwiftData

// MARK: - DUT-78 CloudKit crash-loop self-heal
//
// Adds two guards on top of the existing DUT-6 / DOD-CRASH-1 fallback and the
// DUT-630 Simulator gate, closing the REAL-DEVICE instance of the async
// CloudKit-mirroring-setup trap (see `CloudKitAvailability.swift` +
// `LaunchHealthTracker.swift` for the full writeup):
//
// 1. A pre-open account-status guard: if the host cached a non-`.available`
//    account status from the previous launch's async probe, don't attempt
//    `.private(...)` this launch — open local instead, dodging the async trap
//    rather than trying (and failing) to catch it.
// 2. A self-heal escape hatch: after `LaunchHealthTracker.unhealthyLaunchLimit`
//    consecutive launches that started but never reached `markLaunchHealthy()`
//    (i.e. crash-looped before the scene came up), force a local open
//    regardless of opt-in/account-status so the app becomes launchable again.
//
// `ContainerBuildResult` also lives here (extracted from
// `RecipeStore+Containers.swift` to keep that file under the SwiftLint
// `file_length` cap once the `didSelfHeal` flag was added).

extension RecipeStore {

    /// Outcome of building the production container, distinguishing the
    /// CloudKit-backed open from the DOD-CRASH-1 safety fallback (DUT-6), the
    /// DUT-525 migration-recovery fresh-store rebuild, and the DUT-78
    /// self-heal escape hatch. The host (`AppDependencies`) reads these flags
    /// to log the degraded state; the diagnostics surface keys off
    /// ``usedCloudKitFallback`` so a user whose `.private` open failed (or
    /// couldn't be attempted) sees a sensible status instead of a crash.
    public struct ContainerBuildResult {
        public let container: ModelContainer
        /// `true` when the opt-in flag was ON but we did **not** open
        /// CloudKit-backed and instead opened a plain local container —
        /// either because the synchronous `.private` open threw (the
        /// original DOD-CRASH-1 catch), CloudKit mirroring isn't available
        /// in this runtime (DUT-630, the Simulator), the pre-open
        /// account-status probe said the account wasn't `.available`
        /// (DUT-78 async-trap avoidance), or the self-heal escape hatch
        /// tripped after repeated crash-looping launches (DUT-78). `false`
        /// on the normal opt-in success or any opt-out path.
        public let usedCloudKitFallback: Bool
        /// DUT-525 — `true` when the primary container open threw (a failed
        /// V-chain migration or on-disk corruption) and we recovered by moving
        /// the corrupt store aside and opening a FRESH one, so the user lands in
        /// a working-but-empty app instead of a launch crash-loop. `false` on
        /// the normal path.
        public let recoveredFromMigrationFailure: Bool
        /// DUT-78 — `true` when the self-heal escape hatch
        /// (``LaunchHealthTracker``) force-opened local this launch after
        /// ``LaunchHealthTracker/unhealthyLaunchLimit`` consecutive unhealthy
        /// launches, even though the opt-in flag was ON. The host
        /// force-clears the opt-in flag in this case so the app stays
        /// launchable on the *next* launch without re-tripping the heal.
        /// Implies ``usedCloudKitFallback``.
        public let didSelfHeal: Bool

        public init(
            container: ModelContainer,
            usedCloudKitFallback: Bool,
            recoveredFromMigrationFailure: Bool = false,
            didSelfHeal: Bool = false
        ) {
            self.container = container
            self.usedCloudKitFallback = usedCloudKitFallback
            self.recoveredFromMigrationFailure = recoveredFromMigrationFailure
            self.didSelfHeal = didSelfHeal
        }
    }

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

    /// The DUT-78-hardened production-container build. Layers two new guards
    /// on top of ``productionContainer(defaults:inMemory:cloudKitAvailable:)``
    /// (which already carries the DUT-6 opt-in branch, the DOD-CRASH-1
    /// synchronous catch, and the DUT-630 Simulator gate):
    ///
    /// 1. **Self-heal escape hatch.** When `launchHealth?.shouldSelfHeal` is
    ///    `true` (this install has crash-looped
    ///    ``LaunchHealthTracker/unhealthyLaunchLimit`` times), force a local
    ///    open and flag ``ContainerBuildResult/didSelfHeal`` so the host can
    ///    force-clear the opt-in flag — the last-resort recovery for a trap
    ///    that the guard below didn't anticipate (e.g. a stale/missing cached
    ///    status).
    /// 2. **Pre-open account-status guard.** When `accountStatus` is provided
    ///    (the host probes `CKContainer.accountStatus()` at the END of the
    ///    PREVIOUS launch's `bootstrap()` and caches the result — the build
    ///    here is synchronous, the probe is async, so the cached value is the
    ///    only way a prior probe can reach this decision) and
    ///    `CloudKitAvailability.shouldAttemptCloudKit(given:)` is `false`, we
    ///    fold that into `cloudKitAvailable`, so the underlying build opens a
    ///    plain local container instead of `.private(...)` — dodging the async
    ///    `com.apple.coredata.cloudkit.queue` trap entirely rather than trying
    ///    (and failing) to catch it. `nil` preserves the legacy "attempt
    ///    CloudKit on opt-in" behavior for callers that don't probe.
    ///
    /// On the path that chooses to attempt CloudKit (opt-in, account
    /// available-or-unprobed, no self-heal), the store is marked as
    /// CloudKit-touched (``cloudKitStoreEverOpenedKey``) so a later launch
    /// that must fall back to local can detect the on-disk store is tainted.
    public static func productionContainer(
        defaults: UserDefaults,
        accountStatus: CloudKitAvailability.AccountStatus?,
        launchHealth: LaunchHealthTracker?,
        inMemory: Bool = false,
        cloudKitAvailable: Bool = cloudKitMirroringAvailable
    ) throws -> ContainerBuildResult {
        // DUT-78 self-heal escape hatch: after repeated crash-looping
        // launches WHILE OPTED IN, open local regardless of account status so
        // the app becomes launchable and the user can reach Settings. Flagged
        // so the host force-clears the opt-in flag. Gated on `cloudKitSyncOptIn`
        // — an opted-OUT install never touches CloudKit in the first place, so
        // its unhealthy-launch count (if any, from an unrelated crash) must
        // never force a fallback or flip flags that don't apply to it.
        if cloudKitSyncOptIn(in: defaults), launchHealth?.shouldSelfHeal == true {
            let container = try ModelContainer(
                for: Schema(SchemaV6.models),
                migrationPlan: inMemory ? nil : MigrationPlan.self,
                configurations: localCacheConfiguration(inMemory: inMemory),
                syncedSavedConfiguration(inMemory: inMemory, cloudKit: false)
            )
            return ContainerBuildResult(
                container: container,
                usedCloudKitFallback: true,
                didSelfHeal: true
            )
        }
        // DUT-78 pre-open account-status guard: if the host probed the
        // account and it isn't `.available`, do NOT open `.private(...)` —
        // that is the open that risks the async mirroring trap. `nil` (never
        // probed) preserves the existing `cloudKitAvailable` behavior as-is.
        let attemptCloudKit =
            accountStatus.map(CloudKitAvailability.shouldAttemptCloudKit(given:)) ?? true
        let effectiveCloudKitAvailable = cloudKitAvailable && attemptCloudKit
        if !inMemory, cloudKitSyncOptIn(in: defaults), effectiveCloudKitAvailable {
            // Opt-in + about to attempt `.private(...)`: mark the store
            // CloudKit-touched (DUT-78 taint tracking) BEFORE the attempt, so
            // a later fallback launch can tell the on-disk store was stamped
            // for mirroring even if this attempt itself throws synchronously.
            defaults.set(true, forKey: cloudKitStoreEverOpenedKey)
        }
        return try productionContainer(
            defaults: defaults,
            inMemory: inMemory,
            cloudKitAvailable: effectiveCloudKitAvailable
        )
    }
}

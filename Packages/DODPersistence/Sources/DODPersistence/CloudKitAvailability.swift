import Foundation

#if canImport(CloudKit)
import CloudKit
#endif

/// Pre-open CloudKit availability gate for the DUT-78 crash-loop fix.
///
/// **Why a pre-open check exists (DUT-78).** Opening the `SyncedSaved` store
/// with `.private(...)` kicks off Core Data's *asynchronous* CloudKit
/// mirroring setup on `com.apple.coredata.cloudkit.queue`. When the account
/// is unavailable (signed out of iCloud, restricted, or indeterminate) that
/// async setup can trap with `EXC_BREAKPOINT` **after** the synchronous
/// `ModelContainer(...)` open already returned — so the existing
/// `buildCloudKitWithFallback` do/catch never sees it. The cheapest way to
/// dodge the whole async trap is to **not open `.private(...)` in the first
/// place** when we already know the account can't back it: probe
/// `CKContainer.accountStatus()` *before* choosing the configuration, and fall
/// back to a plain local container (marking ``RecipeStore/ContainerBuildResult``
/// `usedCloudKitFallback`) when the account isn't `.available`.
///
/// **Pure decision, injectable probe.** The "should we attempt CloudKit?"
/// decision is split from the actual `CKContainer` call so the L1 suite can
/// drive every account-status branch on macOS under `swift test` (no device,
/// no iCloud account, no CloudKit entitlement) by injecting a status value —
/// while production routes through the real `CKContainer.accountStatus()`
/// probe. CloudKit symbols are `#if canImport(CloudKit)`-gated so the
/// DODPersistence macOS test slice still compiles where the probe is absent.
public enum CloudKitAvailability: Sendable {

    /// A coarse, CloudKit-free mirror of `CKAccountStatus` so the *decision*
    /// logic (and its L1 tests) never reference the CloudKit type directly.
    /// The host maps the real `CKAccountStatus` into this on device.
    public enum AccountStatus: String, Sendable, Equatable {
        /// Signed into iCloud and the account can back a `.private` DB — the
        /// only status on which it is safe to open `.private(...)`.
        case available
        /// Not signed into iCloud — opening `.private(...)` would risk the
        /// DUT-78 async mirroring trap, so fall back to local.
        case noAccount
        /// Account restricted (parental controls / MDM) — fall back to local.
        case restricted
        /// Status could not be determined (transient) — fall back to local
        /// this launch rather than gamble on the async trap; the next launch
        /// re-probes and engages sync once the account resolves.
        case couldNotDetermine
        /// A status this build doesn't recognize (forward-compat for a future
        /// `CKAccountStatus` case) — treated conservatively as "don't attempt".
        case unknown
    }

    /// `UserDefaults` key caching the last account status the host probed
    /// (DUT-78). The synchronous container build at launch *N+1* reads this
    /// (written by launch *N*'s async `bootstrap()` probe) to decide whether
    /// to open `.private(...)` — because `CKContainer.accountStatus()` is async
    /// and the container build is synchronous, the cached value is how the
    /// pre-open guard reaches the synchronous open path. Absent ⇒ no cached
    /// reading ⇒ legacy "attempt CloudKit on opt-in" behavior (the self-heal
    /// escape hatch still bounds any resulting crash-loop). Versioned (`V1`).
    public static let cachedAccountStatusKey = "dod.cloudkit.cachedAccountStatusV1"

    /// Persist the host's freshly-probed account status for the next launch's
    /// synchronous container build to read (DUT-78). Stored as the stable raw
    /// string so the mapping is decoupled from any enum ordering.
    public static func cacheAccountStatus(
        _ status: AccountStatus,
        in defaults: UserDefaults
    ) {
        defaults.set(status.rawValue, forKey: cachedAccountStatusKey)
    }

    /// Read the cached account status the previous launch probed, or `nil`
    /// when none was ever cached (fresh install / never probed) (DUT-78).
    public static func cachedAccountStatus(
        in defaults: UserDefaults
    ) -> AccountStatus? {
        guard let raw = defaults.string(forKey: cachedAccountStatusKey) else {
            return nil
        }
        return AccountStatus(rawValue: raw)
    }

    /// The decision the container factory acts on: should it *attempt* a
    /// CloudKit-backed `.private(...)` open, or open a plain local container?
    ///
    /// Only ``AccountStatus/available`` yields `true`. Every other status —
    /// and the no-CloudKit-platform path — yields `false`, so the app dodges
    /// the async mirroring trap and degrades to "saved recipes stay on this
    /// device" until the account resolves on a later launch (DUT-78 /
    /// AC-41.1).
    public static func shouldAttemptCloudKit(given status: AccountStatus) -> Bool {
        status == .available
    }

    #if canImport(CloudKit)
    /// Map a real `CKAccountStatus` into the CloudKit-free ``AccountStatus``
    /// (device path). Kept tiny + total so an unrecognized future raw value
    /// lands on ``AccountStatus/unknown`` (conservative "don't attempt")
    /// rather than crashing.
    public static func accountStatus(
        from ckStatus: CKAccountStatus
    ) -> AccountStatus {
        switch ckStatus {
        case .available: return .available
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .couldNotDetermine: return .couldNotDetermine
        @unknown default: return .unknown
        }
    }

    /// Probe the live iCloud account status for `containerIdentifier`
    /// (device path), mapped to the CloudKit-free ``AccountStatus``. **Never
    /// throws / never traps** — a probe failure maps to
    /// ``AccountStatus/couldNotDetermine`` so the caller falls back to local
    /// rather than risking the DUT-78 async open. Marked `async` because
    /// `CKContainer.accountStatus()` is async; the launch path awaits it
    /// before deciding the container configuration.
    public static func probeAccountStatus(
        containerIdentifier: String
    ) async -> AccountStatus {
        let container = CKContainer(identifier: containerIdentifier)
        do {
            let status = try await container.accountStatus()
            return accountStatus(from: status)
        } catch {
            return .couldNotDetermine
        }
    }
    #endif
}

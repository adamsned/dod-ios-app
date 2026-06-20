import CloudKit
import DODPersistence
import DODSupport
import Foundation

// DUT-78 / T-791: extracted from AppDependencies.swift to keep that file under
// the SwiftLint `file_length` cap once the crash-loop self-heal launch wiring
// (the account-status probe + cache) landed alongside the existing CloudKit
// launch diagnostics.
extension AppDependencies {

    /// US-41 / AC-41.1 + AC-41.7 / REG-25 + REG-26 (T-702) + DUT-78 (T-791).
    /// Probe the user's iCloud account status so subsequent sync attempts know
    /// whether to proceed (`.available`) or pause with a status sublabel
    /// (`.noAccount` / `.restricted` / `.couldNotDetermine` — T-705 owns the
    /// sublabel surface). Per AC-41.1 the app **must not crash** when the
    /// account is unavailable — we log + continue, and the existing SwiftData
    /// store keeps working unchanged on the AC-41.1 fallback path.
    ///
    /// Surface trace (REG-25): the only `CKContainer` APIs this path touches
    /// are the initializer + `accountStatus()` (inside
    /// `CloudKitAvailability.probeAccountStatus`). No `publicCloudDatabase` /
    /// `sharedCloudDatabase` / `discoverUserIdentity` surface reference exists
    /// in the entire app per the REG-25 contract.
    func checkCloudKitAvailability() async {
        // DUT-78: route the probe through `CloudKitAvailability.probe…` so the
        // result is mapped to the CloudKit-free `AccountStatus` and CACHED for
        // the NEXT launch's synchronous container build to read (the pre-open
        // guard). `CKContainer.accountStatus()` is async and the container
        // build is sync, so the cached value is the only way the guard can
        // reach the synchronous `.private` decision; this launch's build
        // already happened, so caching now arms the guard for launch N+1.
        let status = await CloudKitAvailability.probeAccountStatus(
            containerIdentifier: RecipeStore.cloudKitContainerIdentifier
        )
        DODLog.app.info("CloudKit account status: \(String(describing: status), privacy: .public)")
        CloudKitAvailability.cacheAccountStatus(status, in: .standard)
    }
}

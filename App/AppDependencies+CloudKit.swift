import CloudKit
import DODPersistence
import DODSupport
import Foundation

// US-41 / AC-41.1 — the CloudKit account-availability probe, extracted from
// `AppDependencies.swift` so that file stays under the SwiftLint `file_length`
// cap. Includes the DUT-671 fold of a non-`.available` account status into the
// Settings status row.
extension AppDependencies {

    /// US-41 / AC-41.1 + AC-41.7 / REG-25 + REG-26 (T-702). Probe the
    /// user's iCloud account status so subsequent sync attempts know
    /// whether to proceed (`.available`) or pause with a status sublabel
    /// (`.noAccount` / `.restricted` / `.couldNotDetermine` — T-705 owns
    /// the sublabel surface). Per AC-41.1 the app **must not crash** when
    /// the account is unavailable — we log + continue, and the existing
    /// SwiftData store keeps working unchanged on the AC-41.1 fallback
    /// path.
    ///
    /// Surface trace (REG-25): the only `CKContainer` APIs this method
    /// touches are the initializer + `accountStatus()`. No
    /// `publicCloudDatabase` / `sharedCloudDatabase` / `discoverUserIdentity`
    /// surface reference exists in the entire app per the REG-25 contract.
    func checkCloudKitAvailability() async {
        // DUT-675 (completes DUT-630) — `CKContainer(identifier:)` traps at INIT
        // (uncatchable by the `accountStatus()` try/catch) without the iCloud
        // entitlement, which adhoc/CLI sim builds strip. Skip on Simulator, where
        // CloudKit sync is untestable anyway — the gate DUT-630 uses for mirroring.
        guard RecipeStore.cloudKitMirroringAvailable else { return }
        let container = CKContainer(identifier: RecipeStore.cloudKitContainerIdentifier)
        do {
            let status = try await container.accountStatus()
            DODLog.app.info("CloudKit account status: \(String(describing: status))")
            // DUT-78: cache the mapped status for the NEXT launch's
            // SYNCHRONOUS container build to read (this probe is async and
            // that build isn't, so caching now is the only way this result
            // can reach that decision — see `CloudKitAvailability` /
            // `RecipeStore+CloudKitSelfHeal.swift`'s pre-open guard).
            CloudKitAvailability.cacheAccountStatus(
                CloudKitAvailability.accountStatus(from: status),
                in: .standard
            )
            // DUT-671 — a non-`.available` account means sync can never run this
            // launch, so surface it in the Settings status row instead of leaving
            // it a falsely-idle "Off". `.available` leaves `latestStatus` to the
            // mirror-event observer (idle / syncing / error).
            if let message = Self.accountUnavailableMessage(for: status) {
                cloudKitDiagnostics.markAccountUnavailable(message)
            }
        } catch {
            DODLog.app.notice("CloudKit availability check failed: \(error.localizedDescription)")
            // DUT-78: a probe failure is exactly "couldn't determine" for the
            // next launch's pre-open guard — safer to fall back to local than
            // to gamble on the async mirroring trap.
            CloudKitAvailability.cacheAccountStatus(.couldNotDetermine, in: .standard)
        }
    }

    /// DUT-671 — map a non-`.available` `CKAccountStatus` to a user-facing
    /// message for the Settings iCloud Sync row; `nil` for `.available` (healthy).
    static func accountUnavailableMessage(for status: CKAccountStatus) -> String? {
        switch status {
        case .available:
            return nil
        case .noAccount:
            return "No iCloud account — sign in to iCloud in Settings to sync."
        case .restricted:
            return "iCloud is restricted on this device; sync is unavailable."
        case .couldNotDetermine, .temporarilyUnavailable:
            return "iCloud account status is unavailable; sync is paused."
        @unknown default:
            return "iCloud account status is unavailable; sync is paused."
        }
    }
}

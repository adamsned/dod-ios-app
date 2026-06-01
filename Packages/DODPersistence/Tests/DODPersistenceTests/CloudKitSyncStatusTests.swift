import Testing

@testable import DODPersistence

/// L1 coverage for the DUT-6 minimal sync-status mapping (cause B). The
/// `displayString` is what the Settings → iCloud Sync row's status sublabel
/// renders; the `init(event:)` maps the `NSPersistentCloudKitContainer`
/// mirror events `CloudKitSyncDiagnostics` observes into the coarse status.
/// Both are pure, so they pin the user-visible copy without a live CloudKit
/// account (mirrors `CloudKitSyncEventSummaryTests`).
@Suite("CloudKitSyncStatus (DUT-6)")
struct CloudKitSyncStatusTests {

    // MARK: - displayString

    @Test func offAndIdleBothRenderIdlePlaceholder() {
        // `off` preserves the pre-DUT-6 reserved "Idle" placeholder the
        // existing SettingsViewModel L1 test pins.
        #expect(CloudKitSyncStatus.off.displayString == "Idle")
        #expect(CloudKitSyncStatus.idle.displayString == "Idle")
    }

    @Test func relaunchPendingRendersRelaunchCopy() {
        #expect(CloudKitSyncStatus.relaunchPending.displayString == "Relaunch DOD to apply")
    }

    @Test func syncingRendersSyncingCopy() {
        #expect(CloudKitSyncStatus.syncing.displayString == "Syncing…")
    }

    @Test func errorRendersSyncErrorCopy() {
        #expect(CloudKitSyncStatus.error("Did not find any record types").displayString == "Sync error")
        // The copy is stable regardless of whether an underlying message rode along.
        #expect(CloudKitSyncStatus.error(nil).displayString == "Sync error")
    }

    // MARK: - Mapping from a mirror event

    @Test func startedEventMapsToSyncing() {
        let summary = CloudKitSyncEventSummary(
            phase: .importData,
            finished: false,
            succeeded: false,
            errorDescription: nil,
            durationSeconds: nil
        )
        #expect(CloudKitSyncStatus(event: summary) == .syncing)
    }

    @Test func finishedSuccessMapsToIdle() {
        let summary = CloudKitSyncEventSummary(
            phase: .export,
            finished: true,
            succeeded: true,
            errorDescription: nil,
            durationSeconds: 0.25
        )
        #expect(CloudKitSyncStatus(event: summary) == .idle)
    }

    @Test func finishedFailureMapsToErrorCarryingDescription() {
        let summary = CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "Did not find any record types",
            durationSeconds: 1.5
        )
        #expect(CloudKitSyncStatus(event: summary) == .error("Did not find any record types"))
    }
}

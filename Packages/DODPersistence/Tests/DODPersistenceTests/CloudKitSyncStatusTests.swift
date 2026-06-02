import CloudKit
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

    /// A finished, failed import with NO error code is the schema-not-deployed
    /// signature — a genuine, actionable failure that must surface as `.error`.
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

    // MARK: - DUT-22: non-fatal failures do NOT map to `.error`

    /// A finished, failed `setup` event (the push-subscription registration
    /// that fails without aps-environment) is bring-up noise — it maps to
    /// `.syncing`, NOT `.error`.
    @Test func finishedSetupFailureMapsToSyncingNotError() {
        let summary = CloudKitSyncEventSummary(
            phase: .setup,
            finished: true,
            succeeded: false,
            errorDescription: "Couldn't create subscription",
            durationSeconds: 0.1,
            errorCode: CKError.Code.missingEntitlement.rawValue
        )
        #expect(CloudKitSyncStatus(event: summary) == .syncing)
    }

    /// A finished import that failed with a transient/auto-retried code (a
    /// network blip) maps to `.syncing`, NOT `.error`.
    @Test func finishedTransientImportFailureMapsToSyncingNotError() {
        let summary = CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "The Internet connection appears to be offline.",
            durationSeconds: 0.5,
            errorCode: CKError.Code.networkUnavailable.rawValue
        )
        #expect(CloudKitSyncStatus(event: summary) == .syncing)
    }

    // MARK: - DUT-22: stateful reconcile

    /// A healthy `.idle` row that sees a non-fatal blip stays `.idle` — the
    /// blip never repaints the row as "Sync error".
    @Test func reconcileIdlePlusNonFatalStaysIdle() {
        let blip = CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "offline",
            durationSeconds: 0.5,
            errorCode: CKError.Code.networkUnavailable.rawValue
        )
        #expect(CloudKitSyncStatus.idle.reconciled(with: blip) == .idle)
    }

    /// A healthy `.idle` row that sees a genuine fatal import failure surfaces
    /// the real error.
    @Test func reconcileIdlePlusFatalBecomesError() {
        let fatal = CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "Did not find any record types",
            durationSeconds: 1.5
        )
        #expect(
            CloudKitSyncStatus.idle.reconciled(with: fatal)
                == .error("Did not find any record types")
        )
    }

    /// A row already showing `.error` is NOT cleared by a later non-fatal blip
    /// — a real failure is never hidden.
    @Test func reconcileErrorPlusNonFatalStaysError() {
        let blip = CloudKitSyncEventSummary(
            phase: .setup,
            finished: true,
            succeeded: false,
            errorDescription: "Couldn't create subscription",
            durationSeconds: 0.1,
            errorCode: CKError.Code.missingEntitlement.rawValue
        )
        let prior = CloudKitSyncStatus.error("Did not find any record types")
        #expect(prior.reconciled(with: blip) == prior)
    }

    /// A mid-cycle `.syncing` row settles to `.idle` once a success arrives.
    @Test func reconcileSyncingPlusSuccessBecomesIdle() {
        let success = CloudKitSyncEventSummary(
            phase: .export,
            finished: true,
            succeeded: true,
            errorDescription: nil,
            durationSeconds: 0.25
        )
        #expect(CloudKitSyncStatus.syncing.reconciled(with: success) == .idle)
    }
}

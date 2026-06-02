import CloudKit
import Testing

@testable import DODPersistence

/// Unit coverage for the round-12 diagnostic formatter. The `init(event:)`
/// mapping is exercised at runtime on-device (an `NSPersistentCloudKitContainer
/// .Event` can't be constructed in a test), so these assert the pure
/// `logLine` rendering that the device logs will show, plus the DUT-22
/// `failureIsFatal` classification that gates the "Sync error" copy.
@Suite("CloudKitSyncEventSummary")
struct CloudKitSyncEventSummaryTests {

    @Test func failedImportRendersPhaseDurationAndError() {
        let summary = CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "Did not find any record types",
            durationSeconds: 1.5
        )
        #expect(
            summary.logLine
                == "CloudKit mirror import FAILED in 1.50s — Did not find any record types"
        )
    }

    @Test func succeededExportRendersOk() {
        let summary = CloudKitSyncEventSummary(
            phase: .export,
            finished: true,
            succeeded: true,
            errorDescription: nil,
            durationSeconds: 0.25
        )
        #expect(summary.logLine == "CloudKit mirror export ok in 0.25s")
    }

    @Test func inProgressStartEventHasNoStageDurationOrError() {
        let summary = CloudKitSyncEventSummary(
            phase: .setup,
            finished: false,
            succeeded: false,
            errorDescription: nil,
            durationSeconds: nil
        )
        #expect(summary.logLine == "CloudKit mirror setup started")
    }

    // MARK: - failureIsFatal (DUT-22)

    /// A finished, failed `setup` event (e.g. the CKDatabaseSubscription
    /// registration that fails without the aps-environment Push entitlement)
    /// is bring-up noise, not an actionable sync failure.
    @Test func setupPhaseFailureIsNotFatal() {
        let summary = CloudKitSyncEventSummary(
            phase: .setup,
            finished: true,
            succeeded: false,
            errorDescription: "Couldn't create subscription",
            durationSeconds: 0.1,
            errorCode: CKError.Code.missingEntitlement.rawValue
        )
        #expect(summary.failureIsFatal == false)
    }

    /// A finished import that failed with a transient/auto-retried CloudKit
    /// code (here a network blip) is recoverable, so it is not fatal.
    @Test func transientCodedImportFailureIsNotFatal() {
        let summary = CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "The Internet connection appears to be offline.",
            durationSeconds: 0.5,
            errorCode: CKError.Code.networkUnavailable.rawValue
        )
        #expect(summary.failureIsFatal == false)
    }

    /// A finished import/export that failed with no error code (the
    /// schema-not-deployed signature) IS a genuine, actionable failure.
    @Test func importFailureWithNoCodeIsFatal() {
        let summary = CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "Did not find any record types",
            durationSeconds: 1.5
        )
        #expect(summary.failureIsFatal == true)
    }

    /// A finished import that failed with a non-transient CKError code (here a
    /// permanently-unavailable account) is still a real, actionable failure.
    @Test func importFailureWithNonTransientCodeIsFatal() {
        let summary = CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "This account is not available.",
            durationSeconds: 0.4,
            errorCode: CKError.Code.notAuthenticated.rawValue
        )
        #expect(summary.failureIsFatal == true)
    }

    /// A successful finished event is never a failure.
    @Test func successIsNotFatal() {
        let summary = CloudKitSyncEventSummary(
            phase: .export,
            finished: true,
            succeeded: true,
            errorDescription: nil,
            durationSeconds: 0.25
        )
        #expect(summary.failureIsFatal == false)
    }

    /// An in-progress (not-yet-finished) event has not failed yet.
    @Test func notFinishedIsNotFatal() {
        let summary = CloudKitSyncEventSummary(
            phase: .importData,
            finished: false,
            succeeded: false,
            errorDescription: nil,
            durationSeconds: nil
        )
        #expect(summary.failureIsFatal == false)
    }
}

import CloudKit
import DODAnalytics
import DODPersistence
import XCTest

@testable import DODApp

/// DUT-1325 — `CloudKitSyncDiagnostics` observes the SwiftData ↔ CloudKit
/// mirror and drives the Settings sync-status row (DUT-6), but never sent the
/// `syncCompletedSuccessfully` / `syncFailed(errorCategory:)` events the
/// constitution has allowlisted since CL-124 (US-41 AC-41.9) — the original
/// T-705 design meant to wire this up was abandoned, and the simpler observer
/// that shipped for the DUT-6 bug never picked the analytics handoff back up.
/// This suite pins the fix by injecting a recording closure into the new
/// `sendTelemetry` seam, mirroring `CardSaveTelemetryTests` (DUT-1322) rather
/// than mutating the process-wide `Telemetry.shared` singleton.
///
/// `NSPersistentCloudKitContainer.Event` has no public initializer, so these
/// tests exercise `reconcile(with:)` directly via `CloudKitSyncEventSummary`'s
/// public memberwise init instead of posting a real notification — the same
/// reason the pre-existing doc comments on `CloudKitSyncEventSummary.init(event:)`
/// say that constructor "is not exercised by unit tests."
@MainActor
final class CloudKitSyncAnalyticsTests: XCTestCase {

    // MARK: - syncCompletedSuccessfully

    func test_finishedSuccessfulCycle_sendsSyncCompletedSuccessfully() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.reconcile(with: .success())

        XCTAssertEqual(recorder.events, [.syncCompletedSuccessfully])
    }

    func test_startedNotYetFinishedCycle_sendsNothing() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.reconcile(with: .started())

        XCTAssertEqual(recorder.events, [], "a started-but-not-finished cycle must send nothing")
    }

    func test_secondSuccessWithin60Seconds_isDebouncedAndSendsNothing() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        diagnostics.recordSyncCompleted(now: t0)
        diagnostics.recordSyncCompleted(now: t0.addingTimeInterval(30))

        XCTAssertEqual(
            recorder.events,
            [.syncCompletedSuccessfully],
            "constitution §9 caps syncCompletedSuccessfully to at most once per 60s"
        )
    }

    func test_secondSuccessAfter60Seconds_sendsAgain() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        diagnostics.recordSyncCompleted(now: t0)
        diagnostics.recordSyncCompleted(now: t0.addingTimeInterval(61))

        XCTAssertEqual(
            recorder.events,
            [.syncCompletedSuccessfully, .syncCompletedSuccessfully],
            "once the 60s window has elapsed, a new successful cycle must send again"
        )
    }

    // MARK: - syncFailed via the mirror-event path

    func test_firstFatalFailure_sendsSyncFailed() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.reconcile(with: .fatalFailure(errorCode: CKError.Code.quotaExceeded.rawValue))

        XCTAssertEqual(recorder.events, [.syncFailed(errorCategory: .quotaExceeded)])
    }

    func test_repeatedFatalFailureWhileAlreadyInError_doesNotResend() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.reconcile(with: .fatalFailure(errorCode: CKError.Code.quotaExceeded.rawValue))
        diagnostics.reconcile(with: .fatalFailure(errorCode: CKError.Code.quotaExceeded.rawValue))
        diagnostics.reconcile(with: .fatalFailure(errorCode: CKError.Code.internalError.rawValue))

        XCTAssertEqual(
            recorder.events,
            [.syncFailed(errorCategory: .quotaExceeded)],
            "a repeat fatal failure while already .error must not re-send syncFailed"
        )
    }

    func test_recoveryThenReFailure_sendsSyncFailedAgain() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.reconcile(with: .fatalFailure(errorCode: CKError.Code.internalError.rawValue))
        diagnostics.reconcile(with: .success())
        diagnostics.reconcile(with: .fatalFailure(errorCode: CKError.Code.notAuthenticated.rawValue))

        XCTAssertEqual(
            recorder.events,
            [
                .syncFailed(errorCategory: .serverInternal),
                .syncCompletedSuccessfully,
                .syncFailed(errorCategory: .accountStatus),
            ],
            "recovering to a success and then failing again must fire syncFailed a second time"
        )
    }

    func test_nonFatalFailure_sendsNothing() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        // .networkUnavailable is in the transient set — failureIsFatal is false,
        // so reconciled(with:) never enters .error and nothing should fire.
        diagnostics.reconcile(with: .fatalFailure(errorCode: CKError.Code.networkUnavailable.rawValue))

        XCTAssertEqual(recorder.events, [], "a transient/non-fatal failure must not send syncFailed")
    }

    func test_setupPhaseFailure_sendsNothing() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.reconcile(
            with: CloudKitSyncEventSummary(
                phase: .setup,
                finished: true,
                succeeded: false,
                errorDescription: "setup failed",
                durationSeconds: 0.1,
                errorCode: nil
            )
        )

        XCTAssertEqual(recorder.events, [], "a setup-phase failure is never fatal, must not send syncFailed")
    }

    // MARK: - Error-category mapping

    func test_errorCategoryMapping_forEachRepresentativeCode() {
        let cases: [(Int, AnalyticsEvent)] = [
            (CKError.Code.quotaExceeded.rawValue, .syncFailed(errorCategory: .quotaExceeded)),
            (CKError.Code.notAuthenticated.rawValue, .syncFailed(errorCategory: .accountStatus)),
            (CKError.Code.internalError.rawValue, .syncFailed(errorCategory: .serverInternal)),
            (CKError.Code.serverRejectedRequest.rawValue, .syncFailed(errorCategory: .serverInternal)),
            (CKError.Code.badContainer.rawValue, .syncFailed(errorCategory: .other)),
        ]
        for (code, expected) in cases {
            let recorder = EventRecorder()
            let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })
            diagnostics.reconcile(with: .fatalFailure(errorCode: code))
            XCTAssertEqual(recorder.events, [expected], "CKError code \(code) must map to \(expected)")
        }
    }

    func test_nilErrorCode_mapsToOther() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.reconcile(with: .fatalFailure(errorCode: nil))

        XCTAssertEqual(recorder.events, [.syncFailed(errorCategory: .other)])
    }

    // MARK: - markContainerOpenFailed / markAccountUnavailable (the two sibling
    // entry points into `.error` outside the mirror-event observer)

    func test_markContainerOpenFailed_sendsSyncFailedOther() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.markContainerOpenFailed()

        XCTAssertEqual(recorder.events, [.syncFailed(errorCategory: .other)])
    }

    func test_markContainerOpenFailed_calledTwice_sendsOnlyOnce() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.markContainerOpenFailed()
        diagnostics.markContainerOpenFailed()

        XCTAssertEqual(
            recorder.events,
            [.syncFailed(errorCategory: .other)],
            "calling markContainerOpenFailed twice must not double-send"
        )
    }

    func test_markAccountUnavailable_sendsSyncFailedAccountStatus() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.markAccountUnavailable("No iCloud account")

        XCTAssertEqual(recorder.events, [.syncFailed(errorCategory: .accountStatus)])
    }

    func test_markAccountUnavailable_afterMirrorEventAlreadyInError_doesNotResend() {
        let recorder = EventRecorder()
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { recorder.record($0) })

        diagnostics.reconcile(with: .fatalFailure(errorCode: CKError.Code.internalError.rawValue))
        diagnostics.markAccountUnavailable("No iCloud account")

        XCTAssertEqual(
            recorder.events,
            [.syncFailed(errorCategory: .serverInternal)],
            "the transition-detection is shared across all three error-setting entry points"
        )
    }

    func test_markAccountUnavailable_alwaysSetsErrorStatus_regardlessOfTelemetryDedup() {
        let diagnostics = CloudKitSyncDiagnostics(sendTelemetry: { _ in })

        diagnostics.reconcile(with: .fatalFailure(errorCode: CKError.Code.internalError.rawValue))
        diagnostics.markAccountUnavailable("No iCloud account")

        guard case .error(let message) = diagnostics.latestStatus else {
            XCTFail("latestStatus must be .error after markAccountUnavailable")
            return
        }
        XCTAssertEqual(
            message,
            "No iCloud account",
            "the status message must always update to the latest reason, even when the "
                + "telemetry dedup suppresses a duplicate syncFailed send"
        )
    }
}

// MARK: - Helpers

extension CloudKitSyncEventSummary {

    fileprivate static func started() -> CloudKitSyncEventSummary {
        CloudKitSyncEventSummary(
            phase: .importData,
            finished: false,
            succeeded: false,
            errorDescription: nil,
            durationSeconds: nil,
            errorCode: nil
        )
    }

    fileprivate static func success() -> CloudKitSyncEventSummary {
        CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: true,
            errorDescription: nil,
            durationSeconds: 0.25,
            errorCode: nil
        )
    }

    fileprivate static func fatalFailure(errorCode: Int?) -> CloudKitSyncEventSummary {
        CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "failed",
            durationSeconds: 0.5,
            errorCode: errorCode
        )
    }
}

/// Thread-safe event sink for the `sendTelemetry` test seam, mirroring
/// `CardSaveTelemetryTests.EventRecorder` (DUT-1322).
private final class EventRecorder: @unchecked Sendable {

    private let lock = NSLock()
    private var _events: [AnalyticsEvent] = []

    var events: [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    func record(_ event: AnalyticsEvent) {
        lock.lock()
        defer { lock.unlock() }
        _events.append(event)
    }
}

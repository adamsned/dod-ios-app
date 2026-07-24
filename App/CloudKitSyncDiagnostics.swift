import CloudKit
import CoreData
import DODAnalytics
import DODPersistence
import DODSupport
import Foundation
import os

/// Diagnostic-only instrumentation for the SwiftData ↔ CloudKit mirror.
///
/// SwiftData opens an `NSPersistentCloudKitContainer` when the store is
/// configured with `cloudKitDatabase: .private(...)` — i.e. the user enabled
/// iCloud Sync. That container posts `eventChangedNotification` for every
/// setup / import / export cycle, start and end. Observing it tells us *which*
/// layer of the mirror is failing on a real device:
///
/// - a never-deployed **Production** schema surfaces as a failed
///   `import`/`export` carrying the underlying `CKError`;
/// - an unavailable **account** surfaces via `checkCloudKitAvailability()`;
/// - a sync that **never turned on** (e.g. the opt-in toggle didn't re-wire
///   the live store) produces no events at all.
///
/// Logs through `DODLog.app` (os.Logger) at `.public` privacy, so the trail is
/// readable in Console.app / Xcode device logs even on a Release / TestFlight
/// build — no debugger attach required. Started from
/// `AppDependencies.bootstrap()` only when the iCloud-Sync opt-in is on,
/// mirroring `checkCloudKitAvailability()`.
///
/// Diagnostic backing for the round-12 backlog bug — "CloudKit recipe sync
/// doesn't work". Pure formatting lives in `CloudKitSyncEventSummary`
/// (DODPersistence); this type is the thin notification glue.
///
/// DUT-1325 (US-41 AC-41.9 / constitution §9) — this is ALSO the only place
/// that can transition `latestStatus` into `.error` or complete a sync cycle,
/// so it now dispatches the `syncCompletedSuccessfully` / `syncFailed`
/// analytics events the constitution has allowlisted since CL-124 but which
/// were never wired up (the original T-705 design that was meant to build
/// this observer never shipped; when a simpler version landed for the DUT-6
/// bug, the T-707 analytics handoff was dropped). All three status-mutating
/// entry points (the mirror-event observer, ``markContainerOpenFailed()``,
/// ``markAccountUnavailable(_:)``) route through the same transition-detecting
/// helper so `syncFailed` fires exactly once per genuine transition into
/// `.error`, regardless of which path caused it — not on every repeat failure
/// while already showing an error.
@MainActor
final class CloudKitSyncDiagnostics {

    /// Guards against double-registration. The observer is deliberately *not*
    /// retained for removal: this instance lives for the whole process (it is
    /// a `let` on the composition root), so the subscription should last the
    /// entire app run — exactly the window we want sync events logged over.
    private var started = false

    /// Latest coarse sync status mapped from the most recent mirror event
    /// (DUT-6, cause B). The Settings → iCloud Sync row reads this (via the
    /// `SettingsDependencies` seam) when it appears, so the status sublabel
    /// can show idle / syncing / error. `.off` until the first event arrives
    /// (or whenever sync is opted out and the observer was never started).
    private(set) var latestStatus: CloudKitSyncStatus = .off

    /// The last time `syncCompletedSuccessfully` was sent, for the constitution
    /// §9 at-most-once-per-60s cap.
    private var lastSyncCompletedSentAt: Date?

    /// Test seam — defaults to the production `Telemetry.shared` singleton so
    /// `AppDependencies`' real construction site is unaffected. Exists purely so
    /// unit tests never mutate the process-wide singleton (mirrors
    /// `TabStack.saveFromCard`'s `sendTelemetry` seam, DUT-1322).
    private let sendTelemetry: @Sendable (AnalyticsEvent) -> Void

    init(sendTelemetry: @escaping @Sendable (AnalyticsEvent) -> Void = { Telemetry.shared.send($0) }) {
        self.sendTelemetry = sendTelemetry
    }

    /// Begin logging CloudKit mirror events. Idempotent — a second call while
    /// already observing is a no-op.
    func start() {
        guard !started else { return }
        started = true
        DODLog.app.info("CloudKit mirror diagnostics: observing sync events")
        _ = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard
                let event = note.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event
            else { return }
            let summary = CloudKitSyncEventSummary(event: event)
            if summary.finished, !summary.succeeded {
                DODLog.app.error("\(summary.logLine, privacy: .public)")
            } else {
                DODLog.app.info("\(summary.logLine, privacy: .public)")
            }
            // The observer fires on the main queue, so this `@MainActor`
            // mutation is safe.
            MainActor.assumeIsolated {
                self?.reconcile(with: summary)
            }
        }
    }

    /// DUT-22 / DUT-1325 — fold one mirror-event summary into `latestStatus`
    /// (via the stateful `reconciled(with:)`, so a non-fatal/transient/setup
    /// blip never repaints a healthy row as "Sync error"), then dispatch
    /// `syncFailed` on a genuine transition into `.error` and
    /// `syncCompletedSuccessfully` on a finished, successful cycle. Extracted
    /// out of the notification closure — which can't be unit-tested,
    /// `NSPersistentCloudKitContainer.Event` has no public initializer — into
    /// its own method so this reconciliation logic IS unit-testable, via
    /// `CloudKitSyncEventSummary`'s public memberwise init.
    func reconcile(with summary: CloudKitSyncEventSummary) {
        let wasError = Self.isErrorCase(latestStatus)
        latestStatus = latestStatus.reconciled(with: summary)
        if !wasError, Self.isErrorCase(latestStatus) {
            sendTelemetry(.syncFailed(errorCategory: Self.errorCategory(forCKErrorCode: summary.errorCode)))
        }
        if summary.finished, summary.succeeded {
            recordSyncCompleted()
        }
    }

    /// Mark that the CloudKit container failed to open at launch (the
    /// DOD-CRASH-1 fallback to a local store). No mirror events fire in that
    /// case, so without this the Settings row would read a falsely-healthy
    /// "Idle". Surface the genuine failure so the user can act (most commonly:
    /// deploy the CloudKit Production schema, then relaunch).
    func markContainerOpenFailed() {
        setErrorStatus(
            "CloudKit container failed to open; sync is paused on this device.",
            errorCategory: .other
        )
    }

    /// DUT-671 — fold a non-`.available` iCloud account status into
    /// `latestStatus`. `checkCloudKitAvailability()` used to only *log* a
    /// `.noAccount` / `.restricted` / `.couldNotDetermine` result, so the
    /// Settings row read an idle "Off" while sync could never actually run.
    /// Surfacing it as an error lets Settings tell the user "no iCloud account"
    /// instead. `.available` is left untouched — the mirror-event observer owns
    /// the healthy idle/syncing states.
    func markAccountUnavailable(_ message: String) {
        setErrorStatus(message, errorCategory: .accountStatus)
    }

    /// Shared transition-detecting error setter behind `markContainerOpenFailed()`
    /// and `markAccountUnavailable(_:)`, mirroring `reconcile(with:)`'s own
    /// wasError-before/isError-after check so all THREE ways `latestStatus` can
    /// become `.error` fire `syncFailed` exactly once per transition, not once
    /// per repeat call while already showing an error.
    private func setErrorStatus(_ message: String, errorCategory: SyncErrorCategory) {
        let wasError = Self.isErrorCase(latestStatus)
        latestStatus = .error(message)
        if !wasError {
            sendTelemetry(.syncFailed(errorCategory: errorCategory))
        }
    }

    /// DUT-1325 — constitution §9 caps `syncCompletedSuccessfully` to at most
    /// once per 60 seconds. `now` is injectable so the debounce window is
    /// unit-testable without sleeping real time (mirrors
    /// `CookLogStats.currentWeeklyStreak(calendar:)`'s injectable-clock
    /// pattern).
    func recordSyncCompleted(now: Date = Date()) {
        if let last = lastSyncCompletedSentAt, now.timeIntervalSince(last) < Self.syncCompletedDebounceInterval {
            return
        }
        lastSyncCompletedSentAt = now
        sendTelemetry(.syncCompletedSuccessfully)
    }

    private static let syncCompletedDebounceInterval: TimeInterval = 60

    private static func isErrorCase(_ status: CloudKitSyncStatus) -> Bool {
        if case .error = status { return true }
        return false
    }

    /// Maps the fatal `CKError.Code` values `reconcile(with:)` can actually see
    /// (`failureIsFatal` already filters out `transientCloudKitErrorCodes`) onto
    /// the closed-set `SyncErrorCategory` the constitution allowlists. `.network`
    /// is included for completeness even though the two network-related codes
    /// are themselves in the transient set (so this specific integration can't
    /// reach it) — `errorCategory` is a general-purpose mapping, not scoped only
    /// to what `reconcile(with:)` happens to feed it today.
    private static func errorCategory(forCKErrorCode code: Int?) -> SyncErrorCategory {
        guard let code else { return .other }
        switch code {
        case CKError.Code.networkUnavailable.rawValue, CKError.Code.networkFailure.rawValue:
            return .network
        case CKError.Code.notAuthenticated.rawValue:
            return .accountStatus
        case CKError.Code.quotaExceeded.rawValue:
            return .quotaExceeded
        case CKError.Code.internalError.rawValue, CKError.Code.serverRejectedRequest.rawValue:
            return .serverInternal
        default:
            return .other
        }
    }
}

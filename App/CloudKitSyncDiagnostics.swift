import CoreData
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
@MainActor
final class CloudKitSyncDiagnostics {

    /// Guards against double-registration. The observer is deliberately *not*
    /// retained for removal: this instance lives for the whole process (it is
    /// a `let` on the composition root), so the subscription should last the
    /// entire app run — exactly the window we want sync events logged over.
    private var started = false

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
        ) { note in
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
        }
    }
}

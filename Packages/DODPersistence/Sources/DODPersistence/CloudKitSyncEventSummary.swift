import CoreData
import Foundation

/// A flattened, log-friendly snapshot of one `NSPersistentCloudKitContainer`
/// mirror event (setup / import / export).
///
/// SwiftData drives a CloudKit-backed `NSPersistentCloudKitContainer` under the
/// hood when the store opens with `cloudKitDatabase: .private(...)` (i.e. the
/// user enabled iCloud Sync). That container posts `eventChangedNotification`
/// at the start and end of every sync cycle. Pulling the handful of fields we
/// care about into a plain `Sendable` value keeps the formatting pure and
/// unit-testable without a live CloudKit account
/// (`NSPersistentCloudKitContainer.Event` has no public initializer).
///
/// Diagnostic backing for the round-12 backlog bug — "CloudKit recipe sync
/// doesn't work". A failed `import`/`export` surfaces the underlying error
/// (e.g. a Production-environment schema that was never deployed), which is
/// exactly the signal needed to tell schema-not-deployed apart from
/// account-unavailable (logged separately) or sync-never-enabled (no events
/// at all). The App-target observer `CloudKitSyncDiagnostics` maps each event
/// to one of these and logs ``logLine`` via `DODLog.app`.
public struct CloudKitSyncEventSummary: Equatable, Sendable {

    /// Which half of the mirror produced the event.
    public enum Phase: String, Sendable {
        case setup
        case importData = "import"
        case export
        case unknown
    }

    /// `setup` / `import` / `export`.
    public let phase: Phase
    /// `true` once the event carries an `endDate` (the cycle finished);
    /// `false` for the paired start event.
    public let finished: Bool
    /// Whether a finished event completed without error. Meaningless until
    /// `finished` is `true`.
    public let succeeded: Bool
    /// `error.localizedDescription` for a failed event, else `nil`.
    public let errorDescription: String?
    /// `endDate - startDate` for a finished event, else `nil`.
    public let durationSeconds: Double?

    public init(
        phase: Phase,
        finished: Bool,
        succeeded: Bool,
        errorDescription: String?,
        durationSeconds: Double?
    ) {
        self.phase = phase
        self.finished = finished
        self.succeeded = succeeded
        self.errorDescription = errorDescription
        self.durationSeconds = durationSeconds
    }

    /// One-line, `os.Logger`-friendly rendering, e.g.
    /// `"CloudKit mirror import FAILED in 1.50s — <error>"` or
    /// `"CloudKit mirror export ok in 0.25s"` or
    /// `"CloudKit mirror setup started"`.
    public var logLine: String {
        let stage = finished ? (succeeded ? "ok" : "FAILED") : "started"
        var line = "CloudKit mirror \(phase.rawValue) \(stage)"
        if let durationSeconds {
            line += String(format: " in %.2fs", durationSeconds)
        }
        if let errorDescription {
            line += " — \(errorDescription)"
        }
        return line
    }
}

extension CloudKitSyncEventSummary {

    /// Flatten a live `NSPersistentCloudKitContainer.Event`. Used by the
    /// App-target observer; not exercised by unit tests because `Event` has no
    /// public initializer.
    public init(event: NSPersistentCloudKitContainer.Event) {
        let phase: Phase
        switch event.type {
        case .setup: phase = .setup
        case .import: phase = .importData
        case .export: phase = .export
        @unknown default: phase = .unknown
        }
        let endDate = event.endDate
        self.init(
            phase: phase,
            finished: endDate != nil,
            succeeded: event.succeeded,
            errorDescription: event.error?.localizedDescription,
            durationSeconds: endDate.map { $0.timeIntervalSince(event.startDate) }
        )
    }
}

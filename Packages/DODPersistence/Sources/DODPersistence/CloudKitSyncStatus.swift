import Foundation

/// A coarse, user-facing summary of the SwiftData ↔ CloudKit mirror's
/// current state, derived from the `NSPersistentCloudKitContainer` mirror
/// events that `CloudKitSyncDiagnostics` already observes (DUT-6, cause B).
///
/// This is the minimal status surface the Settings → iCloud Sync row shows
/// in its existing status sublabel (``displayString``). It deliberately
/// stays a small, closed set — idle / syncing / error / relaunch-pending /
/// off — rather than the richer "Last synced N ago" taxonomy the original
/// T-705 brief sketched (that work, and the `CloudKitSyncAdapter` it
/// assumed, was never built — sync is SwiftData-automatic). Keeping it a
/// pure `Sendable` value with no Foundation-date formatting makes the
/// status-mapping unit-testable without a live CloudKit account, exactly
/// like ``CloudKitSyncEventSummary``.
public enum CloudKitSyncStatus: Equatable, Sendable {

    /// Sync is opted out (the AC-41.1 default) — saved recipes stay on this
    /// device. Also the resting state before any mirror event is observed.
    case off

    /// The opt-in flag was flipped this session; SwiftData builds its
    /// container once per process, so the new on/off state only engages on
    /// the next cold launch. Surfacing this stops the "I toggled it and
    /// nothing synced" confusion (DUT-6).
    case relaunchPending

    /// Sync is on and the mirror is currently importing or exporting.
    case syncing

    /// Sync is on and the last completed mirror cycle succeeded (or none has
    /// run yet this launch). The neutral steady state.
    case idle

    /// The last completed mirror cycle failed — most commonly because the
    /// CloudKit *Production* schema was never deployed (the top DUT-6
    /// suspect), or the iCloud account is unavailable. Carries the
    /// underlying error text for the (debug) status surface.
    case error(String?)

    /// The status sublabel copy shown under the iCloud Sync row. Pinned
    /// strings so the snapshot baselines + VoiceOver paths stay stable.
    ///
    /// `off` renders `"Idle"` — historically the row's reserved placeholder
    /// (the status row only renders when sync is ON, but keeping the OFF
    /// mapping at `"Idle"` preserves the pre-DUT-6 default the existing L1
    /// test pins).
    public var displayString: String {
        switch self {
        case .off, .idle:
            return "Idle"
        case .relaunchPending:
            return "Relaunch DOD to apply"
        case .syncing:
            return "Syncing…"
        case .error:
            return "Sync error"
        }
    }

    /// Map a finished/started mirror event into a coarse status. Only
    /// meaningful while sync is ON; the host gates the call on the opt-in
    /// flag. A started (not-yet-finished) event ⇒ ``syncing``; a finished
    /// success ⇒ ``idle``; a finished failure ⇒ ``error``.
    public init(event summary: CloudKitSyncEventSummary) {
        guard summary.finished else {
            self = .syncing
            return
        }
        self = summary.succeeded ? .idle : .error(summary.errorDescription)
    }
}

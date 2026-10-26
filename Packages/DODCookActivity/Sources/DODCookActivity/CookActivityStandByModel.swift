import Foundation

/// DUT-991: what the full-screen StandBy cook face shows, derived from the
/// same `ContentState` that drives the Lock Screen card (no new data model).
public struct CookActivityStandByModel: Equatable, Sendable {
    public enum Status: Equatable, Sendable { case running, paused, done }

    public let status: Status
    /// Step text, or "Cook Mode" when empty (mirrors the Lock Screen card).
    public let stepText: String
    /// Static fallback countdown (used when paused / done / no endDate).
    public let staticCountdown: String
    /// Non-nil only when the countdown should self-tick.
    public let tickingRange: ClosedRange<Date>?

    public init(state: CookActivityAttributes.ContentState, now: Date = Date()) {
        if state.isCompleted { status = .done } else if state.isPaused { status = .paused } else { status = .running }
        stepText = state.stepText.isEmpty ? "Cook Mode" : state.stepText
        staticCountdown = formattedCookActivityCountdown(state.remainingSeconds)
        if status == .running, let end = state.endDate, now < end {
            tickingRange = now...end
        } else {
            tickingRange = nil
        }
    }
}

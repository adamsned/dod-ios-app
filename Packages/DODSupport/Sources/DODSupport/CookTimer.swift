import Foundation

/// A single named cooking countdown (US-47 / DUT-100 — the multi-timer feature).
///
/// This is a pure value type: the remaining-time math is a function of an
/// injected "now", so ``CookTimerEngine``'s behavior is deterministically
/// unit-testable without waiting on the wall clock. The engine that owns a list
/// of these drives the Live Activity, Cook Mode tray, and notifications in
/// later slices.
public struct CookTimer: Identifiable, Sendable, Equatable {

    /// A timer is either counting down to a wall-clock `endDate`, frozen with a
    /// fixed `remaining` while paused, or done.
    public enum State: Sendable, Equatable {
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
        case finished
    }

    public let id: UUID
    /// User-facing name, e.g. "Cinnamon Rolls — bake". Derived by the caller
    /// from the step/recipe.
    public let label: String
    /// The originally requested duration (seconds) — kept for display ("25:00")
    /// and for a future "restart" affordance, independent of elapsed time.
    public let duration: TimeInterval
    public private(set) var state: State

    public init(id: UUID, label: String, duration: TimeInterval, state: State) {
        self.id = id
        self.label = label
        self.duration = duration
        self.state = state
    }

    /// Seconds left at `now`, clamped to `>= 0`. A running timer counts down to
    /// its `endDate`; a paused timer holds its frozen value; finished is `0`.
    public func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .running(let endDate):
            return max(0, endDate.timeIntervalSince(now))
        case .paused(let remaining):
            return max(0, remaining)
        case .finished:
            return 0
        }
    }

    /// `true` once a running timer has reached or passed its `endDate` at `now`
    /// (or is already finished). Paused timers never elapse.
    public func hasElapsed(at now: Date) -> Bool {
        switch state {
        case .running(let endDate):
            return now >= endDate
        case .finished:
            return true
        case .paused:
            return false
        }
    }

    // MARK: - Pure transitions (return a new value; never mutate in place)

    /// Pause a running timer, freezing the remaining time as of `now`. A no-op
    /// for paused/finished timers.
    public func paused(at now: Date) -> CookTimer {
        guard case .running = state else { return self }
        var copy = self
        copy.state = .paused(remaining: remaining(at: now))
        return copy
    }

    /// Resume a paused timer, re-anchoring its `endDate` to `now + remaining`.
    /// A no-op for running/finished timers.
    public func resumed(at now: Date) -> CookTimer {
        guard case .paused(let remaining) = state else { return self }
        var copy = self
        copy.state = .running(endDate: now.addingTimeInterval(remaining))
        return copy
    }

    /// Mark as finished (used by the engine when a running timer elapses).
    public func finishedTimer() -> CookTimer {
        var copy = self
        copy.state = .finished
        return copy
    }

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }
}

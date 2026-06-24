import Foundation

/// DUT-293 / DUT-294 — the state of a single Cook Mode step's countdown, owned by
/// ``CookModeViewModel`` (keyed by step index) rather than the `CookTimer` view's
/// `@State`. Moving it into the view model is what lets a running timer **keep
/// counting while you browse other steps** (the persist model), stops one step
/// from showing another step's countdown (the `@State`-reuse leak, DUT-293), and
/// lets the VM reconcile the Live Activity so navigating away never strands a
/// ghost card (DUT-294).
///
/// Running timers are stored as an absolute `endDate` so the in-app display can
/// self-tick from `Date.now` (a `TimelineView`) and survive the view going off
/// screen — mirroring how the Lock Screen card self-ticks (DUT-218).
public struct CookStepTimer: Equatable, Sendable {

    /// The original parsed duration, in seconds — drives the progress arc + Reset.
    public let totalSeconds: Int

    public enum State: Equatable, Sendable {
        /// Parsed but not yet started (or just Reset). Shows `totalSeconds`.
        case idle
        /// Counting down; finishes at `endDate`.
        case running(endDate: Date)
        /// Frozen with `remaining` seconds left; Start resumes from here.
        case paused(remaining: Int)
        /// Reached zero.
        case completed
    }

    public var state: State

    public init(totalSeconds: Int, state: State = .idle) {
        self.totalSeconds = max(totalSeconds, 0)
        self.state = state
    }

    /// Seconds left at `now`. Computed from `endDate` while running so the value
    /// is correct no matter how long the view was off screen.
    public func remaining(at now: Date) -> Int {
        switch state {
        case .idle: return totalSeconds
        case .running(let endDate): return max(0, Int(endDate.timeIntervalSince(now).rounded()))
        case .paused(let remaining): return max(0, remaining)
        case .completed: return 0
        }
    }

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    public var didComplete: Bool {
        state == .completed
    }
}

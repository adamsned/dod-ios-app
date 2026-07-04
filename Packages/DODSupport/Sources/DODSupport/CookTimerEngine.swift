import Foundation
import Observation

/// Owns the set of active cooking countdowns (US-47 / DUT-100). `@Observable`
/// so SwiftUI surfaces (the Cook Mode timer tray, the Live Activity bridge)
/// re-render as timers tick; `@MainActor` because it's UI-facing state.
///
/// **Testability.** All wall-clock reads go through the injected `clock`, and
/// state only advances when ``refresh()`` is called — so a test can drive a
/// controllable clock and assert exact transitions with no real waiting. In the
/// app, a lightweight repeating tick (a later slice) calls ``refresh()`` ~1×/s.
@Observable
@MainActor
public final class CookTimerEngine {

    public private(set) var timers: [CookTimer] = []

    /// Fired once per timer at the moment ``refresh()`` transitions it to
    /// `.finished` — the hook the notification/haptic/Live-Activity layer uses.
    @ObservationIgnored public var onFinished: ((CookTimer) -> Void)?

    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let makeID: () -> UUID

    public init(
        clock: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.clock = clock
        self.makeID = makeID
    }

    /// Start a new running countdown of `duration` seconds named `label`.
    /// Returns the created timer (for the caller to track / surface). A
    /// non-positive duration is ignored (returns nil) — nothing to count down.
    @discardableResult
    public func start(label: String, duration: TimeInterval, recipeID: Int? = nil) -> CookTimer? {
        guard duration > 0 else { return nil }
        let now = clock()
        let timer = CookTimer(
            id: makeID(),
            label: label,
            duration: duration,
            state: .running(endDate: now.addingTimeInterval(duration)),
            recipeID: recipeID
        )
        timers.append(timer)
        return timer
    }

    public func pause(_ id: CookTimer.ID) {
        mutate(id) { $0.paused(at: clock()) }
    }

    public func resume(_ id: CookTimer.ID) {
        mutate(id) { $0.resumed(at: clock()) }
    }

    /// Remove a timer entirely (the user cancelled it).
    public func cancel(_ id: CookTimer.ID) {
        timers.removeAll { $0.id == id }
    }

    /// Drop all finished timers (e.g. when the user dismisses the "done" state).
    public func clearFinished() {
        timers.removeAll { $0.state == .finished }
    }

    /// DUT-255 — drop only the finished timers belonging to `recipeID`. The
    /// guided path shares ONE engine across every rung (DUT-484 / DUT-547), so a
    /// per-rung "clear Timer's Up!" affordance must not tear down a sibling
    /// rung's finished (or still-running) bake. A `nil` recipeID clears the
    /// finished timers not tied to any recipe.
    public func clearFinished(for recipeID: Int?) {
        timers.removeAll { $0.state == .finished && $0.recipeID == recipeID }
    }

    public var hasActiveTimers: Bool {
        timers.contains { $0.isRunning }
    }

    /// The running timer that will finish soonest — what the Live Activity /
    /// Dynamic Island shows when several are running. Nil when none are running.
    public var soonestFinishing: CookTimer? {
        let now = clock()
        return
            timers
            .filter(\.isRunning)
            .min { $0.remaining(at: now) < $1.remaining(at: now) }
    }

    /// Advance any running timer that has elapsed to `.finished`, firing
    /// ``onFinished`` exactly once for each newly-finished timer. Idempotent: a
    /// timer already `.finished` is not re-fired. Called on each wall-clock tick.
    public func refresh() {
        let now = clock()
        for index in timers.indices {
            guard timers[index].isRunning, timers[index].hasElapsed(at: now) else { continue }
            timers[index] = timers[index].finishedTimer()
            onFinished?(timers[index])
        }
    }

    // MARK: - Private

    private func mutate(_ id: CookTimer.ID, _ transform: (CookTimer) -> CookTimer) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        timers[index] = transform(timers[index])
    }
}

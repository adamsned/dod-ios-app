import Foundation

// DUT-293 / DUT-294 — the Cook Mode step-timer state machine. Lives in the view
// model (not the `CookTimer` view's `@State`) so a running timer keeps counting
// while you browse other steps (persist model), one step never shows another's
// countdown, and the single Live Activity is reconciled to the soonest-finishing
// timer so navigating away never strands a ghost card. Split from
// `CookModeViewModel.swift` for the SwiftLint file-length cap.
extension CookModeViewModel {

    /// The countdown for a given step index, if one has been offered / started.
    public func timer(forStep index: Int) -> CookStepTimer? {
        stepTimers[index]
    }

    /// Start — or resume from pause — the countdown for `index`. `totalSeconds`
    /// is the parsed duration (used only when no timer exists yet; a resume keeps
    /// the remaining time). Already-running / completed timers are a no-op, as is
    /// a non-positive duration.
    public func startOrResumeTimer(forStep index: Int, totalSeconds: Int, now: Date = Date()) {
        let existing = stepTimers[index]
        let total = existing?.totalSeconds ?? max(totalSeconds, 0)
        guard total > 0 else { return }
        let remaining: Int
        switch existing?.state {
        case .paused(let value): remaining = value
        case .running, .completed: return  // already running / done
        case .idle, .none: remaining = total
        }
        guard remaining > 0 else { return }
        var timer = existing ?? CookStepTimer(totalSeconds: total)
        timer.state = .running(endDate: now.addingTimeInterval(TimeInterval(remaining)))
        stepTimers[index] = timer
        reconcileLiveActivity(now: now)
    }

    /// Pause the countdown for `index`, freezing the remaining time.
    public func pauseTimer(forStep index: Int, now: Date = Date()) {
        guard var timer = stepTimers[index], timer.isRunning else { return }
        timer.state = .paused(remaining: timer.remaining(at: now))
        stepTimers[index] = timer
        reconcileLiveActivity(now: now)
    }

    /// Reset the countdown for `index` to its full duration, stopped.
    public func resetTimer(forStep index: Int, now: Date = Date()) {
        guard var timer = stepTimers[index] else { return }
        timer.state = .idle
        stepTimers[index] = timer
        reconcileLiveActivity(now: now)
    }

    /// Advance all running timers to `now`: any that reached zero flip to
    /// `.completed` (bumping the haptic trigger), then the Live Activity is
    /// reconciled. Called ~1×/s by `CookModeView` while Cook Mode is on screen —
    /// regardless of which step is displayed, so a backgrounded-step timer still
    /// completes (DUT-293/294).
    public func tickTimers(now: Date = Date()) {
        var completedAny = false
        for (key, timer) in stepTimers where timer.isRunning && timer.remaining(at: now) <= 0 {
            var done = timer
            done.state = .completed
            stepTimers[key] = done
            completedAny = true
        }
        if completedAny { timerCompletionTick &+= 1 }
        reconcileLiveActivity(now: now)
    }

    /// DUT-294 — drive the single Live Activity to the soonest-finishing RUNNING
    /// step timer (or end it when none run), so navigating between steps never
    /// leaves a stale card for a step you left.
    func reconcileLiveActivity(now: Date) {
        let soonest =
            stepTimers
            .compactMap { key, timer -> (key: Int, end: Date)? in
                if case .running(let end) = timer.state { return (key, end) }
                return nil
            }
            .min { $0.end < $1.end }

        guard let soonest, let timer = stepTimers[soonest.key] else {
            if liveActivityStepKey != nil {
                endTimerLiveActivity()
                liveActivityStepKey = nil
            }
            return
        }
        let text = stepText(forStep: soonest.key)
        if liveActivityStepKey != soonest.key {
            // A different (or no) timer was driving the card — (re)start so its
            // step text + total match the timer now in charge.
            startTimerLiveActivity(stepText: text, totalSeconds: timer.totalSeconds)
            liveActivityStepKey = soonest.key
        }
        updateTimerLiveActivity(remainingSeconds: timer.remaining(at: now), stepText: text, isPaused: false)
    }

    private func stepText(forStep index: Int) -> String {
        guard index >= 0, index < recipe.instructions.count else { return "" }
        // DUT-349: clamp before it enters the Live Activity ContentState — ActivityKit
        // hard-limits the encoded state to ~4KB, and a full multi-sentence recipe step
        // can blow past it (silently failing the request). The card renders 2 lines.
        return String(recipe.instructions[index].text.prefix(240))
    }
}

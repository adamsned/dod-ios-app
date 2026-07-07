import DODSupport
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
        // DUT-604: schedule the backgrounded "step timer done" alert at the
        // deadline. Fire-and-forget — the notifier no-ops without permission /
        // when notifications are toggled off. A resume re-schedules from the
        // (possibly reduced) remaining time; the request id is per-step so it
        // replaces this step's prior pending request rather than stacking.
        let recipeID = recipe.id
        let seconds = TimeInterval(remaining)
        Task { await stepTimerNotifier.scheduleStepDone(after: seconds, recipeID: recipeID, stepIndex: index) }
    }

    /// Pause the countdown for `index`, freezing the remaining time.
    public func pauseTimer(forStep index: Int, now: Date = Date()) {
        guard var timer = stepTimers[index], timer.isRunning else { return }
        timer.state = .paused(remaining: timer.remaining(at: now))
        stepTimers[index] = timer
        reconcileLiveActivity(now: now)
        // DUT-604: a paused timer isn't counting down, so cancel its pending
        // background alert. A subsequent resume re-schedules from the frozen
        // remaining time. DUT-686: pending-only — a pause must not yank a banner
        // that already fired and the cook hasn't acknowledged.
        cancelPendingStepDoneNotification(forStep: index)
    }

    /// Reset the countdown for `index` to its full duration, stopped.
    public func resetTimer(forStep index: Int, now: Date = Date()) {
        guard var timer = stepTimers[index] else { return }
        timer.state = .idle
        stepTimers[index] = timer
        reconcileLiveActivity(now: now)
        // DUT-604: reset stops the countdown — drop its pending alert.
        cancelStepDoneNotification(forStep: index)
    }

    /// DUT-604 — cancel the pending AND delivered background alert for `index`.
    /// For explicit user-driven stops/resets, which acknowledge the alert.
    /// Fire-and-forget wrapper so the timer methods read cleanly.
    private func cancelStepDoneNotification(forStep index: Int) {
        let recipeID = recipe.id
        Task { await stepTimerNotifier.cancelStepDone(recipeID: recipeID, stepIndex: index) }
    }

    /// DUT-686 — cancel only the PENDING background alert for `index`, leaving an
    /// already-delivered banner in place. For non-acknowledging paths (pause, a
    /// foreground finish) where yanking a fired banner would rob the cook of an
    /// alert they haven't seen. Fire-and-forget wrapper.
    private func cancelPendingStepDoneNotification(forStep index: Int) {
        let recipeID = recipe.id
        Task { await stepTimerNotifier.cancelPendingStepDone(recipeID: recipeID, stepIndex: index) }
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
            // DUT-604: this timer finished IN THE FOREGROUND (the tick loop only
            // runs while Cook Mode is on screen), so the in-app buzzer + Live
            // Activity "done" state cover it — cancel the pending system banner so
            // the cook doesn't get a redundant alert. The `deliveryGrace` on the
            // scheduled request keeps it pending until now, so this cancel lands
            // before it fires. DUT-686: pending-only — if the banner ALREADY fired
            // (the app was backgrounded past the deadline, then returned to the
            // foreground where this tick runs), leave the delivered banner alone
            // so the cook isn't robbed of an alert they haven't acknowledged.
            cancelPendingStepDoneNotification(forStep: key)
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
            // No RUNNING timer. DUT-354: if the timer that was driving the card
            // just COMPLETED, keep the card up on a frozen 0:00 "done" state (the
            // buzzer moment) — Ned's call: it lingers until the cook leaves Cook
            // Mode (endCookMode ends it) or starts another timer (which takes the
            // card over below). Push it ONCE — the flag guards per-tick re-pushes
            // while it lingers. Any other reason the driving timer is gone — Reset
            // (→ .idle) or cleared — still ends the card, preserving DUT-294's
            // no-stale-card guarantee.
            if let key = liveActivityStepKey, stepTimers[key]?.state == .completed {
                if !liveActivityShowingCompleted {
                    // DUT-490 / DUT-491: push a first-class "done" state — renders
                    // "Done" (not "Paused") and, via `isCompleted`, gets a
                    // far-future stale date so this single push outlives the
                    // linger instead of dimming after ~15s. Per-tick re-push
                    // suppression stays (the flag below).
                    updateTimerLiveActivity(
                        remainingSeconds: 0,
                        stepText: stepText(forStep: key),
                        isPaused: true,
                        isCompleted: true
                    )
                    liveActivityShowingCompleted = true
                }
            } else if liveActivityStepKey != nil {
                endTimerLiveActivity()
                liveActivityStepKey = nil
                liveActivityShowingCompleted = false
            }
            return
        }
        liveActivityShowingCompleted = false  // DUT-354: a running timer drives the card again
        let text = stepText(forStep: soonest.key)
        if liveActivityStepKey != soonest.key {
            // DUT-558: Live Activities are permanently unavailable (disabled in
            // Settings / over quota). Don't churn `start` (→ auth-check +
            // `endExistingActivity` no-op) every ~1s. The latch is cleared on
            // scene-activate via `revalidateLiveActivityAvailability()`.
            if liveActivityUnavailable { return }
            // A different (or no) timer was driving the card — (re)start so its
            // step text + total match the timer now in charge.
            startTimerLiveActivity(stepText: text, totalSeconds: timer.totalSeconds)
            // DUT-492: only claim the key once the activity actually started. A
            // failed `start` (ActivityKit quota / authorization) leaves the card
            // dead; claiming the key anyway made `liveActivityStepKey ==
            // soonest.key` true on the next tick, so `start` was never retried.
            // Guarding on `isActive` lets the next tick re-attempt the start.
            guard hasLiveActivity else {
                // DUT-558: distinguish a permanent "activities unavailable" from a
                // transient start failure. Only latch (and stop retrying) when the
                // controller reports activities are disabled/over quota; a genuine
                // transient failure leaves the latch clear so DUT-492's next-tick
                // retry still fires.
                if !areLiveActivitiesEnabled { liveActivityUnavailable = true }
                return
            }
            liveActivityStepKey = soonest.key
        }
        updateTimerLiveActivity(remainingSeconds: timer.remaining(at: now), stepText: text, isPaused: false)
    }

    private func stepText(forStep index: Int) -> String {
        guard index >= 0, index < recipe.instructions.count else { return "" }
        // DUT-440: match the on-screen + spoken step (DUT-245) — the Lock
        // Screen card must not show 350°F while the app says 175°C.
        var text = recipe.instructions[index].text
        let rawUnit = UserDefaults.standard.string(forKey: TemperatureConverter.preferenceKey)
        if let unit = TemperatureConverter.resolvedUnit(fromRawValue: rawUnit) {
            text = TemperatureConverter.converting(text, to: unit)
        }
        // DUT-349: clamp before it enters the Live Activity ContentState — ActivityKit
        // hard-limits the encoded state to ~4KB, and a full multi-sentence recipe step
        // can blow past it (silently failing the request). The card renders 2 lines.
        return String(text.prefix(240))
    }
}

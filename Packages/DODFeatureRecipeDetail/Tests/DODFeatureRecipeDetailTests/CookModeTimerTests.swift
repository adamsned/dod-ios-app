import DODCookActivity
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-293 / DUT-294 — the Cook Mode step-timer state machine now lives in
/// `CookModeViewModel` (keyed by step index), not the `CookTimer` view's
/// `@State`. That's what makes it unit-testable AND what delivers the persist
/// model: a running timer keeps counting while you browse other steps, one step
/// never shows another's countdown, and the single Live Activity follows the
/// soonest-finishing timer so navigating away never strands a ghost card.
@MainActor
@Suite("Cook Mode step timers (DUT-293/294)")
struct CookModeTimerTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func startingATimerRunsItAndDrivesTheLiveActivity() {
        let spy = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 2, liveActivity: spy)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 120, now: t0)

        #expect(vm.timer(forStep: 0)?.isRunning == true)
        #expect(vm.timer(forStep: 0)?.remaining(at: t0) == 120)
        #expect(spy.isActive)
    }

    /// The persist core: a running timer keeps counting after you navigate away.
    @Test func aRunningTimerKeepsCountingAcrossStepNavigation() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 120, now: t0)
        vm.goNext()  // → step 1
        vm.goNext()  // → step 2; step 0's timer must keep running

        let step0 = vm.timer(forStep: 0)
        #expect(step0?.isRunning == true)
        #expect(step0?.remaining(at: t0.addingTimeInterval(30)) == 90)
    }

    @Test func pauseFreezesRemainingThenResumeContinues() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(40))  // 60 left

        // Frozen — wall-clock passing doesn't drain a paused timer.
        #expect(vm.timer(forStep: 0)?.isRunning == false)
        #expect(vm.timer(forStep: 0)?.remaining(at: t0.addingTimeInterval(999)) == 60)

        // Resume much later: it continues from 60, not from elapsed time.
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0.addingTimeInterval(500))
        #expect(vm.timer(forStep: 0)?.remaining(at: t0.addingTimeInterval(500)) == 60)
    }

    /// DUT-354 — when a timer completes while the app is foregrounded, the Live
    /// Activity must NOT vanish the instant it hits zero. It lingers on a frozen
    /// 0:00 "done" state (the buzzer moment) until the cook leaves Cook Mode or
    /// starts another timer.
    @Test func tickToZeroCompletesBumpsHapticAndKeepsTheBuzzerCard() {
        let spy = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, liveActivity: spy)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 5, now: t0)
        let before = vm.timerCompletionTick
        vm.tickTimers(now: t0.addingTimeInterval(6))  // past the deadline

        #expect(vm.timer(forStep: 0)?.didComplete == true)
        #expect(vm.timerCompletionTick == before + 1)
        #expect(spy.isActive == true)  // DUT-354: card lingers on the finished state
        #expect(spy.lastUpdateState?.remainingSeconds == 0)
        #expect(spy.lastUpdateState?.isPaused == true)  // frozen 0:00, not a live-ticking countdown
        // DUT-490 / DUT-491: the linger push is a first-class "done" state — it
        // renders "Done" (not "Paused") and gets a far-future stale date.
        #expect(spy.lastUpdateState?.isCompleted == true)
        #expect(spy.lastUpdateState?.endDate == nil)  // frozen snapshot, not self-ticking
    }

    /// DUT-490 / DUT-491 — while the buzzer card lingers, per-tick reconciles
    /// must NOT re-push (the suppression flag). The single completed push is the
    /// only one, so nothing refreshes the stale date away, and its `isCompleted`
    /// flag is what the controller keys the far-future stale date off of.
    @Test func lingeringBuzzerCardIsPushedExactlyOnceAsCompleted() {
        let spy = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, liveActivity: spy)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 5, now: t0)
        vm.tickTimers(now: t0.addingTimeInterval(6))  // completes → single done push
        let updatesAfterCompletion = spy.updateCallCount

        // Several more ticks while it lingers — no additional pushes.
        vm.tickTimers(now: t0.addingTimeInterval(20))
        vm.tickTimers(now: t0.addingTimeInterval(40))
        #expect(spy.updateCallCount == updatesAfterCompletion)  // suppressed
        #expect(spy.lastUpdateState?.isCompleted == true)
    }

    /// DUT-492 — a FAILED `start` (ActivityKit quota/authorization) must NOT
    /// claim `liveActivityStepKey`; otherwise the next tick sees the key already
    /// set and never retries, leaving the card dead for the whole timer. With the
    /// fix, the key stays nil so the next tick re-attempts the start — and once
    /// authorization flips on, the card comes up.
    @Test func failedLiveActivityStartIsRetriedOnTheNextTick() {
        let spy = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, liveActivity: spy)

        spy.startShouldFail = true
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 120, now: t0)

        #expect(spy.startCallCount == 1)  // attempted
        #expect(spy.isActive == false)  // but failed
        #expect(vm.liveActivityStepKey == nil)  // DUT-492: key NOT claimed for a dead card

        // Authorization flips on; the next tick must retry the start.
        spy.startShouldFail = false
        vm.tickTimers(now: t0.addingTimeInterval(1))

        #expect(spy.startCallCount == 2)  // retried
        #expect(spy.isActive == true)
        #expect(vm.liveActivityStepKey == 0)  // now claimed
    }

    /// DUT-354 — resetting a completed timer (→ .idle) dismisses the lingering
    /// buzzer card, preserving DUT-294's no-stale-card guarantee.
    @Test func resettingACompletedTimerEndsTheLingeringCard() {
        let spy = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, liveActivity: spy)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 5, now: t0)
        vm.tickTimers(now: t0.addingTimeInterval(6))  // completes → card lingers
        #expect(spy.isActive == true)

        vm.resetTimer(forStep: 0, now: t0.addingTimeInterval(7))
        #expect(spy.isActive == false)  // reset dismisses the finished card
    }

    @Test func resetReturnsToIdleAndEndsLiveActivity() {
        let spy = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, liveActivity: spy)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 60, now: t0)
        vm.resetTimer(forStep: 0, now: t0.addingTimeInterval(10))

        #expect(vm.timer(forStep: 0)?.remaining(at: t0) == 60)  // back to full
        #expect(vm.timer(forStep: 0)?.isRunning == false)
        #expect(spy.isActive == false)
    }

    /// DUT-294 — the single Live Activity follows the soonest-finishing timer.
    @Test func liveActivityFollowsTheSoonestFinishingTimer() {
        let spy = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3, liveActivity: spy)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 600, now: t0)  // 10 min
        vm.startOrResumeTimer(forStep: 1, totalSeconds: 60, now: t0)  // 1 min — sooner

        #expect(spy.startedAttributes?.totalSeconds == 60)  // re-pointed to the sooner one
        #expect(spy.lastUpdateState?.stepText == "Step 2 body.")  // index 1 → step 2
    }

    @Test func endCookModeClearsAllTimersAndEndsTheCard() {
        let spy = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 2, liveActivity: spy)

        vm.beginCookMode()
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 120, now: t0)
        vm.endCookMode()

        #expect(vm.stepTimers.isEmpty)
        #expect(spy.isActive == false)
    }
}

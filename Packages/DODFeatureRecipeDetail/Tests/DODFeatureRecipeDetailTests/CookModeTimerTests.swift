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

    @Test func tickToZeroCompletesBumpsHapticAndEndsLiveActivity() {
        let spy = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, liveActivity: spy)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 5, now: t0)
        let before = vm.timerCompletionTick
        vm.tickTimers(now: t0.addingTimeInterval(6))  // past the deadline

        #expect(vm.timer(forStep: 0)?.didComplete == true)
        #expect(vm.timerCompletionTick == before + 1)
        #expect(spy.isActive == false)  // card ended on completion
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

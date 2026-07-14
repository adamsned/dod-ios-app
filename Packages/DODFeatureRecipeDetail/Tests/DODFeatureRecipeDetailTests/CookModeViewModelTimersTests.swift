import DODCookActivity
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-293 / DUT-294 — unit tests for the timer state machine in
/// `CookModeViewModel+Timers.swift`. Focuses on step-indexed orchestration,
/// state transitions, and edge cases. Complements the integrated behavior
/// tests in `CookModeTimerTests.swift`.
@MainActor
@Suite("CookModeViewModel+Timers state transitions")
struct CookModeViewModelTimersTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func timerRetrievalReturnsNilForNonexistentStep() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 2)
        #expect(vm.timer(forStep: 99) == nil)
    }

    @Test func timerRetrievalReturnsStartedTimer() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 2)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        let timer = vm.timer(forStep: 0)
        #expect(timer?.totalSeconds == 100)
        #expect(timer?.isRunning == true)
    }

    @Test func startWithZeroDurationIsANoOp() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 0, now: t0)
        #expect(vm.timer(forStep: 0) == nil)
    }

    @Test func startWithNegativeDurationIsANoOp() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: -50, now: t0)
        #expect(vm.timer(forStep: 0) == nil)
    }

    @Test func startCreatesRunningTimerWithCorrectEndDate() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 120, now: t0)
        let timer = vm.timer(forStep: 0)
        #expect(timer?.isRunning == true)
        #expect(timer?.remaining(at: t0) == 120)
        let elapsed = t0.addingTimeInterval(30)
        #expect(timer?.remaining(at: elapsed) == 90)
    }

    @Test func startOnRunningTimerIsANoOp() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.startOrResumeTimer(
            forStep: 0,
            totalSeconds: 100,
            now: t0.addingTimeInterval(40)
        )
        // The timer's state unchanged — still running from original start.
        #expect(
            vm.timer(forStep: 0)?.remaining(at: t0.addingTimeInterval(40))
                == 60
        )
    }

    @Test func startOnCompletedTimerIsANoOp() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 5, now: t0)
        vm.tickTimers(now: t0.addingTimeInterval(10))  // completes
        #expect(vm.timer(forStep: 0)?.didComplete == true)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0.addingTimeInterval(11))
        // Completed timers reject resume — stays completed.
        #expect(vm.timer(forStep: 0)?.didComplete == true)
        #expect(vm.timer(forStep: 0)?.isRunning == false)
    }

    @Test func pauseNonexistentTimerIsANoOp() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.pauseTimer(forStep: 0, now: t0)
        #expect(vm.timer(forStep: 0) == nil)
    }

    @Test func pauseIdleTimerIsANoOp() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.resetTimer(forStep: 0)  // → idle
        vm.pauseTimer(forStep: 0, now: t0)  // no-op on idle
        #expect(vm.timer(forStep: 0)?.state == .idle)
    }

    @Test func pauseFreezesTheRemainingTime() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(30))

        #expect(vm.timer(forStep: 0)?.isRunning == false)
        // Time passes; remaining must NOT change.
        #expect(
            vm.timer(forStep: 0)?.remaining(at: t0.addingTimeInterval(999))
                == 70
        )
    }

    @Test func pauseWellBeforeDeadlineFreezesNormally() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(10))

        let timer = vm.timer(forStep: 0)
        #expect(timer?.didComplete == false)
        #expect(timer?.isRunning == false)
        if case .paused(let remaining) = timer?.state {
            #expect(remaining == 90)
        } else {
            #expect(false, "Expected paused state")
        }
    }

    /// DUT-962 regression — pause AFTER deadline must complete, not strand at
    /// paused(0). Before the fix, it froze forever and couldn't be resumed.
    @Test func pauseAfterDeadlineCompletesRatherThanFreezingAtZero() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 5, now: t0)
        let completionTickBefore = vm.timerCompletionTick

        // Pause 0.4s past the deadline.
        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(5.4))

        #expect(vm.timer(forStep: 0)?.didComplete == true)
        // Completion tick must have bumped (haptic signal).
        #expect(vm.timerCompletionTick == completionTickBefore + 1)
        // Attempting resume must be a no-op (completed timer rejects it).
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 5, now: t0.addingTimeInterval(6))
        #expect(vm.timer(forStep: 0)?.isRunning == false)
    }

    /// Edge case — pause EXACTLY at zero remaining (not yet past) must also
    /// complete per DUT-962.
    @Test func pauseExactlyAtDeadlineAlsoCompletes() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 5, now: t0)
        let before = vm.timerCompletionTick

        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(5))

        #expect(vm.timer(forStep: 0)?.didComplete == true)
        #expect(vm.timerCompletionTick == before + 1)
    }

    @Test func resetReturnsToIdleState() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.resetTimer(forStep: 0, now: t0.addingTimeInterval(40))

        let timer = vm.timer(forStep: 0)
        #expect(timer?.state == .idle)
        #expect(timer?.remaining(at: t0) == 100)  // back to full
        #expect(timer?.isRunning == false)
    }

    @Test func resetNonexistentTimerIsANoOp() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.resetTimer(forStep: 0)
        #expect(vm.timer(forStep: 0) == nil)
    }

    @Test func tickDoesNotAdvanceIdleOrPausedTimers() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 2)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(30))
        vm.startOrResumeTimer(forStep: 1, totalSeconds: 100, now: t0)
        vm.resetTimer(forStep: 1)  // → idle

        vm.tickTimers(now: t0.addingTimeInterval(50))

        // Paused timer stays frozen.
        #expect(
            vm.timer(forStep: 0)?.remaining(at: t0.addingTimeInterval(50))
                == 70
        )
        // Idle timer stays at full.
        #expect(
            vm.timer(forStep: 1)?.remaining(at: t0.addingTimeInterval(50))
                == 100
        )
    }

    @Test func tickAdvancesRunningTimersCorrectly() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.tickTimers(now: t0.addingTimeInterval(40))

        #expect(
            vm.timer(forStep: 0)?.remaining(at: t0.addingTimeInterval(40))
                == 60
        )
    }

    @Test func tickCompletesTimersThatReachedZero() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 50, now: t0)
        let before = vm.timerCompletionTick

        vm.tickTimers(now: t0.addingTimeInterval(100))

        #expect(vm.timer(forStep: 0)?.didComplete == true)
        #expect(vm.timerCompletionTick == before + 1)
    }

    @Test func tickCompletesMultipleTimersInOneCall() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 30, now: t0)
        vm.startOrResumeTimer(forStep: 1, totalSeconds: 50, now: t0)
        vm.startOrResumeTimer(forStep: 2, totalSeconds: 20, now: t0)
        let before = vm.timerCompletionTick

        // All should complete.
        vm.tickTimers(now: t0.addingTimeInterval(100))

        #expect(vm.timer(forStep: 0)?.didComplete == true)
        #expect(vm.timer(forStep: 1)?.didComplete == true)
        #expect(vm.timer(forStep: 2)?.didComplete == true)
        // Completion tick bumps once per tick, not per timer.
        #expect(vm.timerCompletionTick == before + 1)
    }

    @Test func multipleTimersAreStoredAndManagedIndependently() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.startOrResumeTimer(forStep: 2, totalSeconds: 60, now: t0)

        #expect(vm.timer(forStep: 0)?.totalSeconds == 100)
        #expect(vm.timer(forStep: 1) == nil)
        #expect(vm.timer(forStep: 2)?.totalSeconds == 60)

        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(20))
        #expect(vm.timer(forStep: 0)?.isRunning == false)
        #expect(vm.timer(forStep: 2)?.isRunning == true)
    }

    @Test func resumeFromPauseUsesFrozenRemainingNotElapsedTime() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        // Pause at 40s elapsed (60s remaining).
        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(40))

        // Resume MUCH later, from the frozen 60s, not from elapsed time.
        vm.startOrResumeTimer(
            forStep: 0,
            totalSeconds: 100,
            now: t0.addingTimeInterval(500)
        )
        #expect(
            vm.timer(forStep: 0)?.remaining(at: t0.addingTimeInterval(500))
                == 60
        )
    }
}

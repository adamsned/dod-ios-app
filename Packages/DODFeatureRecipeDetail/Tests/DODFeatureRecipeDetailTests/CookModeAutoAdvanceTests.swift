import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-173 — advance and undo logic in `CookModeViewModel+AutoAdvance.swift`.
@MainActor
@Suite("CookModeViewModel+AutoAdvance")
struct CookModeAutoAdvanceTests {

    @Test func enabledAdvancesAndRemembersOrigin() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        vm.autoAdvanceEnabled = true
        let advanced = vm.autoAdvanceAfterTimer(completedStep: 0)
        #expect(advanced)
        #expect(vm.currentStepIndex == 1)
        #expect(vm.pendingAutoAdvanceFromStep == 0)
    }

    @Test func disabledDoesNothing() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        vm.autoAdvanceEnabled = false
        let advanced = vm.autoAdvanceAfterTimer(completedStep: 0)
        #expect(!advanced)
        #expect(vm.currentStepIndex == 0)
        #expect(vm.pendingAutoAdvanceFromStep == nil)
    }

    @Test func lastStepDoesNotFinish() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        vm.autoAdvanceEnabled = true
        vm.goToStep(2)
        let advanced = vm.autoAdvanceAfterTimer(completedStep: 2)
        #expect(!advanced)
        #expect(!vm.isFinished)
        #expect(vm.currentStepIndex == 2)
    }

    @Test func undoReturnsToOriginAndClearsPending() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        vm.autoAdvanceEnabled = true
        vm.autoAdvanceAfterTimer(completedStep: 0)
        vm.undoAutoAdvance()
        #expect(vm.currentStepIndex == 0)
        #expect(vm.pendingAutoAdvanceFromStep == nil)
    }

    @Test func dismissClearsPendingWithoutMoving() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        vm.autoAdvanceEnabled = true
        vm.autoAdvanceAfterTimer(completedStep: 0)
        vm.dismissAutoAdvanceBanner()
        #expect(vm.currentStepIndex == 1)
        #expect(vm.pendingAutoAdvanceFromStep == nil)
    }

    @Test func timerCompletionAdvancesToNextStep() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        let t0 = Date()
        vm.autoAdvanceEnabled = true
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 60, now: t0)
        // Advance to step 0 and tick the timer to completion
        vm.goToStep(0)
        vm.tickTimers(now: t0.addingTimeInterval(61))
        #expect(vm.currentStepIndex == 1)
        #expect(vm.timerCompletionTick == 1)
    }

    @Test func timerCompletionDoesNotAdvanceWhenSettingOff() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        let t0 = Date()
        vm.autoAdvanceEnabled = false
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 60, now: t0)
        // Advance to step 0 and tick the timer to completion
        vm.goToStep(0)
        vm.tickTimers(now: t0.addingTimeInterval(61))
        #expect(vm.currentStepIndex == 0)
        #expect(vm.timerCompletionTick == 1)
    }

    @Test func timerCompletionDoesNotAdvanceOnLastStep() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        let t0 = Date()
        vm.autoAdvanceEnabled = true
        vm.startOrResumeTimer(forStep: 2, totalSeconds: 60, now: t0)
        // Advance to step 2 (last step) and tick the timer to completion
        vm.goToStep(2)
        vm.tickTimers(now: t0.addingTimeInterval(61))
        #expect(vm.currentStepIndex == 2)
        #expect(vm.isFinished == false)
        #expect(vm.timerCompletionTick == 1)
    }
}

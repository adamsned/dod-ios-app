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
}

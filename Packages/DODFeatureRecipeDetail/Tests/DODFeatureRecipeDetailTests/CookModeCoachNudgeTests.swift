import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-967 — `CookModeViewModel.currentCoachNudge`.
@MainActor
@Suite("CookModeViewModel coach nudge")
struct CookModeCoachNudgeTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func nudgeAtFirstStepContainsYouveGotThis() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        let nudge = vm.currentCoachNudge
        #expect(nudge != nil)
        #expect(nudge?.contains("You've got this") == true)
    }

    @Test func nudgeWithRunningTimerMentionsCoals() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.goNext()
        vm.startOrResumeTimer(forStep: 1, totalSeconds: 100, now: t0)
        #expect(vm.currentStepIndex == 1)
        #expect(vm.currentCoachNudge?.contains("coals") == true)
    }
}

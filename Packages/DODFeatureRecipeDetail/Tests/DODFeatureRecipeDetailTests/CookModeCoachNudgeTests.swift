import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-967 — `CookModeViewModel.currentCoachNudge`.
@MainActor
@Suite("CookModeViewModel coach nudge")
struct CookModeCoachNudgeTests {

    @Test func nudgeAtFirstStepContainsYouveGotThis() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        let nudge = vm.currentCoachNudge
        #expect(nudge != nil)
        #expect(nudge?.contains("You've got this") == true)
    }
}

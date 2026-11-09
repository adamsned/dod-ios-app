import DODCookActivity
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel Live Activity Coach Nudge") struct CookModeLiveActivityCoachTests {

    @Test func startedActivityCarriesCoachNudge() {
        let fake = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3, liveActivity: fake)
        vm.startTimerLiveActivity(stepText: "Sear", totalSeconds: 60)
        #expect(fake.lastInitialState?.coachNudge != nil)
    }

    @Test func updatedActivityCarriesCoachNudge() {
        let fake = FakeLiveActivityController()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3, liveActivity: fake)
        vm.startTimerLiveActivity(stepText: "Sear", totalSeconds: 60)
        vm.updateTimerLiveActivity(remainingSeconds: 30, stepText: "Sear", isPaused: false)
        #expect(fake.lastUpdateState?.coachNudge == vm.currentCoachNudge)
    }
}

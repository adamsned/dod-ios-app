import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1392 — which tools the floating Cook Mode dock shows for a step, and the
/// "go to the step whose timer is running" jump.
@MainActor
@Suite("Cook Mode tool dock (DUT-1392)")
struct CookModeToolDockTests {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func running(_ remainingSeconds: Int) -> CookStepTimer {
        CookStepTimer(totalSeconds: 900, state: .running(endDate: now.addingTimeInterval(Double(remainingSeconds))))
    }

    private func resolve(
        _ text: String?,
        index: Int = 0,
        finished: Bool = false,
        heatCoach: Bool = true,
        timers: [Int: CookStepTimer] = [:]
    ) -> CookModeToolDockContent {
        CookModeToolDockContent.resolve(
            currentStepIndex: index,
            stepText: finished ? nil : text,
            heatCoachAvailable: heatCoach,
            timers: timers,
            now: now
        )
    }

    @Test func plainStepHasNoDock() {
        #expect(resolve("Stir in the cheese.").isEmpty)
    }

    @Test func timedStepShowsItsTimer() {
        let content = resolve("Simmer for 10 minutes.")
        #expect(content.stepTimerDuration == .seconds(600))
        #expect(!content.showsHeatCoach)
    }

    @Test func heatStepShowsHeatCoachOnlyWhenWired() {
        #expect(resolve("Preheat the oven to 350°F.").showsHeatCoach)
        #expect(resolve("Arrange 16 coals on the lid.").showsHeatCoach)
        #expect(!resolve("Preheat the oven to 350°F.", heatCoach: false).showsHeatCoach)
    }

    @Test func timedHeatStepShowsBoth() {
        let content = resolve("Bake at 350°F for 25 minutes.")
        #expect(content.stepTimerDuration == .seconds(1500))
        #expect(content.showsHeatCoach)
    }

    /// A timer still running on another step keeps showing after you move on,
    /// picking the one that finishes soonest.
    @Test func runningTimerOnAnotherStepIsShownSoonestFirst() {
        let timers = [0: running(600), 2: running(120), 3: CookStepTimer(totalSeconds: 60)]
        let content = resolve("Stir in the cheese.", index: 4, timers: timers)
        #expect(content.runningTimerStepIndex == 2)
        #expect(!content.isEmpty)
    }

    /// The current step's own timer is shown by the timer card, never twice.
    @Test func currentStepsOwnRunningTimerIsNotRepeated() {
        let content = resolve("Simmer for 10 minutes.", index: 1, timers: [1: running(600)])
        #expect(content.runningTimerStepIndex == nil)
    }

    @Test func doneCardHasNoDock() {
        #expect(resolve("Simmer for 10 minutes.", finished: true, timers: [0: running(60)]).isEmpty)
        #expect(resolve(nil).isEmpty)
    }

    @Test func goToStepJumpsAndLeavesDone() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 4)
        viewModel.goNext()
        viewModel.goNext()
        viewModel.goNext()
        viewModel.goNext()  // Done
        #expect(viewModel.isFinished)

        viewModel.goToStep(1)

        #expect(!viewModel.isFinished)
        #expect(viewModel.currentStepIndex == 1)
        viewModel.goToStep(99)  // out of range: ignored
        #expect(viewModel.currentStepIndex == 1)
    }
}

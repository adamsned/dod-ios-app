import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel (US-7)") struct CookModeViewModelTests {

    // MARK: - Navigation (AC-7.4)

    @Test func nextAdvancesOneStepAtATime() {
        let viewModel = Self.makeViewModel(stepCount: 3)
        #expect(viewModel.currentStepIndex == 0)
        viewModel.goNext()
        #expect(viewModel.currentStepIndex == 1)
        viewModel.goNext()
        #expect(viewModel.currentStepIndex == 2)
    }

    @Test func previousReversesOneStep() {
        let viewModel = Self.makeViewModel(stepCount: 3)
        viewModel.goNext()
        viewModel.goNext()
        viewModel.goBack()
        #expect(viewModel.currentStepIndex == 1)
        viewModel.goBack()
        #expect(viewModel.currentStepIndex == 0)
    }

    @Test func previousAtFirstStepIsAnInertNoOp() {
        let viewModel = Self.makeViewModel(stepCount: 3)
        viewModel.goBack()
        viewModel.goBack()
        #expect(viewModel.currentStepIndex == 0)
        #expect(!viewModel.isFinished)
    }

    @Test func nextOnLastStepFlipsToFinished() {
        let viewModel = Self.makeViewModel(stepCount: 2)
        viewModel.goNext()
        #expect(viewModel.isOnLastStep)
        #expect(!viewModel.isFinished)
        viewModel.goNext()
        // AC-7.4 — "Done" state, no auto-loop back to step 1.
        #expect(viewModel.isFinished)
        #expect(viewModel.currentStepIndex == 1, "Index should stay on last step")
    }

    @Test func backOutOfDoneReturnsToLastStep() {
        let viewModel = Self.makeViewModel(stepCount: 2)
        viewModel.goNext()
        viewModel.goNext()
        #expect(viewModel.isFinished)
        viewModel.goBack()
        #expect(!viewModel.isFinished)
        #expect(viewModel.currentStepIndex == 1)
    }

    @Test func singleStepRecipeImmediatelyOnLastStep() {
        let viewModel = Self.makeViewModel(stepCount: 1)
        #expect(viewModel.isOnLastStep)
        viewModel.goNext()
        #expect(viewModel.isFinished)
    }

    // MARK: - Ingredient state (AC-7.5)

    @Test func seedingIngredientsCarriesThroughInitialState() {
        let id1 = UUID()
        let id2 = UUID()
        let viewModel = Self.makeViewModel(stepCount: 1, seed: [id1, id2])
        #expect(viewModel.checkedIngredientIDs == [id1, id2])
    }

    @Test func toggleIngredientAddsAndRemoves() {
        let id = UUID()
        let viewModel = Self.makeViewModel(stepCount: 1)
        viewModel.toggleIngredient(id)
        #expect(viewModel.checkedIngredientIDs.contains(id))
        viewModel.toggleIngredient(id)
        #expect(!viewModel.checkedIngredientIDs.contains(id))
    }

    // MARK: - Idle timer (AC-7.3, AC-7.6)

    @Test func beginCookModeDisablesIdleTimer() {
        let idleTimer = FakeIdleTimerController()
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        #expect(!idleTimer.isDisabled)
        viewModel.beginCookMode()
        #expect(idleTimer.isDisabled, "AC-7.3 — screen-stay-awake must be on")
    }

    @Test func endCookModeRestoresPriorIdleTimerValue() {
        let idleTimer = FakeIdleTimerController()
        idleTimer.isDisabled = false  // baseline
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        viewModel.beginCookMode()
        #expect(idleTimer.isDisabled)
        viewModel.endCookMode()
        #expect(!idleTimer.isDisabled, "AC-7.3 — exit must restore prior value")
    }

    @Test func beginAndEndAreSymmetricAcrossReEntries() {
        // Re-entering Cook Mode after a clean exit must leave the device
        // back in its starting state — guards against the "battery still
        // draining hours later" bug.
        let idleTimer = FakeIdleTimerController()
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        viewModel.beginCookMode()
        viewModel.endCookMode()
        viewModel.beginCookMode()
        viewModel.endCookMode()
        #expect(!idleTimer.isDisabled)
    }

    @Test func beginIsIdempotent() {
        let idleTimer = FakeIdleTimerController()
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        viewModel.beginCookMode()
        viewModel.beginCookMode()
        viewModel.beginCookMode()
        // Repeated begin must not clobber the captured "prior" value —
        // otherwise endCookMode would leave the device with isDisabled=true
        // for the second begin/end pair.
        #expect(idleTimer.isDisabled)
        viewModel.endCookMode()
        #expect(!idleTimer.isDisabled, "Prior value should still be the original baseline")
    }

    @Test func endWithoutBeginIsANoOp() {
        // The view's .onDisappear can fire without .onAppear in some
        // SwiftUI lifecycle paths; the toggle must not corrupt prior state.
        let idleTimer = FakeIdleTimerController()
        idleTimer.isDisabled = true  // some other surface had it on
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        viewModel.endCookMode()
        #expect(idleTimer.isDisabled, "endCookMode without begin must not change anything")
    }

    @Test func isIdleTimerDisabledProxiesUnderlyingController() {
        let idleTimer = FakeIdleTimerController()
        let viewModel = Self.makeViewModel(stepCount: 1, idleTimer: idleTimer)
        #expect(viewModel.isIdleTimerDisabled == false)
        viewModel.beginCookMode()
        #expect(viewModel.isIdleTimerDisabled == true)
    }

    // MARK: - Helpers

    static func makeViewModel(
        stepCount: Int,
        seed: Set<UUID> = [],
        idleTimer: IdleTimerController = FakeIdleTimerController()
    ) -> CookModeViewModel {
        let instructions = (1...max(stepCount, 1)).map { index in
            RecipeInstruction(step: index, text: "Step \(index) body.")
        }
        let recipe = Recipe(
            id: 100,
            slug: "cook-mode-recipe",
            title: "Cook Mode Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/100/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            instructions: stepCount > 0 ? instructions : []
        )
        return CookModeViewModel(
            recipe: recipe,
            initialCheckedIngredients: seed,
            idleTimer: idleTimer
        )
    }
}

@MainActor
final class FakeIdleTimerController: IdleTimerController {
    var isDisabled: Bool = false
}

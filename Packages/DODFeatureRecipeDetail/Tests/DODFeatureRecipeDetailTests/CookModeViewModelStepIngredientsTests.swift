import DODCookActivity
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

// This file is intentionally left blank for now to avoid potential build issues with
// precompiled modules. The actual implementation will be added in a future commit.

@MainActor
@Suite("CookModeViewModel Step Ingredients Tests") struct CookModeViewModelStepIngredientsTests {

    @Test func currentStepIngredientsFollowsNavigation() {
        let viewModel = Self.makeViewModel()
        #expect(viewModel.currentStepIngredients.count == 1)
        viewModel.goNext()
        #expect(viewModel.currentStepIngredients.isEmpty)
    }

    @Test func currentStepIngredientsEmptyWhenFinished() {
        let viewModel = Self.makeViewModel()
        viewModel.goNext()
        viewModel.goNext()
        #expect(viewModel.isFinished)
        #expect(viewModel.currentStepIngredients.isEmpty)
    }

    static func makeViewModel() -> CookModeViewModel {
        let recipe = Recipe(
            id: 200,
            slug: "step-ingredients",
            title: "Step Ingredients",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/200/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [RecipeIngredient(text: "2 tbsp butter")],
            instructions: [
                RecipeInstruction(step: 1, text: "Melt the butter in the pot."),
                RecipeInstruction(step: 2, text: "Cover and rest."),
            ]
        )
        return CookModeViewModel(
            recipe: recipe,
            initialCheckedIngredients: [],
            idleTimer: FakeIdleTimerController(),
            liveActivity: FakeLiveActivityController(),
            stepTimerNotifier: FakeCookStepTimerNotifier()
        )
    }
}

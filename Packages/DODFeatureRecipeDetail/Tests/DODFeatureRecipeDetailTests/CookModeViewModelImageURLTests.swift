import DODCookActivity
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel Image URL Tests") struct CookModeViewModelImageURLTests {

    @Test func stepImageURLsAreCorrectlyHandled() {
        // DUT-170 — test that step images are properly displayed
        let recipe = Recipe(
            id: 100,
            slug: "cook-mode-recipe",
            title: "Cook Mode Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/100/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            instructions: [
                RecipeInstruction(step: 1, text: "Sear", imageURL: URL(string: "https://e.com/a.jpg")),
                RecipeInstruction(step: 2, text: "Rest"),
            ]
        )
        let viewModel = CookModeViewModel(
            recipe: recipe,
            initialCheckedIngredients: [],
            idleTimer: FakeIdleTimerController(),
            liveActivity: FakeLiveActivityController(),
            stepTimerNotifier: FakeCookStepTimerNotifier()
        )

        #expect(viewModel.currentStep?.imageURL == URL(string: "https://e.com/a.jpg"))

        // Advance to next step
        viewModel.goNext()
        #expect(viewModel.currentStep?.imageURL == nil)
    }
}

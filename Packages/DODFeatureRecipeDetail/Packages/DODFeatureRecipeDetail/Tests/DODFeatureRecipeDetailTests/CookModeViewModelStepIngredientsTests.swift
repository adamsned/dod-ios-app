import DODCookActivity
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel step ingredients (DUT-168)") struct CookModeViewModelStepIngredientsTests {

    @Test func stepIngredientsIsComputedAtInitAndIndexAligned() {
        let viewModel = Self.makeViewModel()
        #expect(viewModel.stepIngredients.count == 2)
        #expect(viewModel.stepIngredients[0].map(\.text) == ["2 tbsp butter"])
        #expect(viewModel.stepIngredients[1].isEmpty)
    }

    static func makeViewModel() -> CookModeViewModel {
        let recipe = Recipe(
            id: 101,
            slug: "step-ingredients-recipe",
            title: "Step Ingredients Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/101/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [RecipeIngredient(text: "2 tbsp butter")],
            instructions: [
                RecipeInstruction(step: 1, text: "Melt the butter."),
                RecipeInstruction(step: 2, text: "Stir."),
            ]
        )
        return CookModeViewModel(
            recipe: recipe,
            initialCheckedIngredients: [],
            idleTimer: FakeIdleTimerController(),
            liveActivity: FakeLiveActivityController(),
            stepTimerNotifier: FakeCookStepTimerNotifier(),
            voiceReader: VoiceReader()
        )
    }
}

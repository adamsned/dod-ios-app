import Foundation
import Testing

@testable import DODIntelligence

@Suite("FakeAskRecipe")
struct FakeAskRecipeTests {
    @Test func fakeAskRecipeReturnsCannedAnswerWhenAvailable() async {
        let service = FakeIntelligenceService()
        let answer = await service.askRecipe("Can I make this ahead?", toolbox: Self.makeToolbox())
        #expect(answer == "Yes. Chill it overnight and reheat gently.")
    }

    @Test func fakeAskRecipeNilWhenUnavailable() async {
        let service = FakeIntelligenceService(isAvailable: false)
        let answer = await service.askRecipe("Can I make this ahead?", toolbox: Self.makeToolbox())
        #expect(answer == nil)
    }

    private static func makeToolbox() -> AskRecipeToolbox {
        AskRecipeToolbox(
            title: "Test Recipe",
            servings: 4,
            scaledIngredients: [
                "2 cups flour",
                "1 cup sugar",
                "3 eggs",
                "1 cup butter",
            ],
            steps: [
                "Preheat oven to 350°F.",
                "Mix ingredients together.",
                "Bake for 30 minutes.",
                "Cool before serving.",
            ]
        )
    }
}

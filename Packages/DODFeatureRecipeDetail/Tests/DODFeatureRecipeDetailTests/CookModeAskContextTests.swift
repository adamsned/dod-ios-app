import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1385 — the plain-text recipe Cook Mode sends with each "Ask the Recipe"
/// question, and (DUT-2895) the chips it offers.
@Suite("CookModeView recipe chat context")
struct CookModeAskContextTests {

    private static func context(
        servings: Int? = 4,
        scale: Double = 1,
        step: Int = 0,
        finished: Bool = false
    ) -> String {
        let recipe = RecipeDetailTestFixtures.makeRecipe(id: 900, withDetail: true, servings: servings)
        return CookModeView.recipeChatContext(
            recipe: recipe,
            ingredientLines: ["1 tsp salt", "1/2 tsp pepper"],
            scaleFactor: scale,
            currentStepIndex: step,
            isFinished: finished
        )
    }

    @Test func includesTitleIngredientsStepsAndCurrentStep() {
        let text = Self.context()
        #expect(text.contains("Recipe: Recipe 900"))
        #expect(text.contains("- 1 tsp salt"))
        #expect(text.contains("- 1/2 tsp pepper"))
        #expect(text.contains("1. Stir."))
        #expect(text.contains("Total time: 15 min"))
        #expect(text.contains("currently on step 1 of 1"))
    }

    @Test func notesScaledServings() {
        #expect(Self.context(servings: 4).contains("Servings: 4"))
        #expect(Self.context(servings: 4, scale: 2).contains("Servings: 8 (scaled from 4)"))
    }

    @Test func saysWhenTheCookIsFinished() {
        #expect(Self.context(finished: true).contains("finished all the steps"))
    }

    @Test func formatsDurations() {
        #expect(CookModeView.minutesText(.seconds(45 * 60)) == "45 min")
        #expect(CookModeView.minutesText(.seconds(120 * 60)) == "2 hr")
        #expect(CookModeView.minutesText(.seconds(75 * 60)) == "1 hr 15 min")
    }

    /// DUT-2895 — Cook Mode's chips follow the servings on screen: a 4-serving
    /// recipe offers "double", but scaled to 8 it offers "half".
    @Test func suggestionsFollowScaledServings() {
        let recipe = RecipeDetailTestFixtures.makeRecipe(id: 901, withDetail: true, servings: 4)
        let plain = CookModeView.recipeChatSuggestions(recipe: recipe, scaleFactor: 1)
        let doubled = CookModeView.recipeChatSuggestions(recipe: recipe, scaleFactor: 2)
        #expect(plain.contains("How do I double this recipe?"))
        #expect(doubled.contains("How do I make half of this?"))
        #expect(!plain.isEmpty && plain.count <= 4)
    }
}

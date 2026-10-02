import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1385 — the plain-text recipe Cook Mode sends with each "Ask About This
/// Recipe" question.
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
}

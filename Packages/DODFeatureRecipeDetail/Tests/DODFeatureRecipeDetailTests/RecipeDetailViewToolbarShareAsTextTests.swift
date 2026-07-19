import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// Coverage for the "Share as Text" bug fix: `RecipeDetailView.shareAsTextPayload`
/// must share the SCALED (+ metric-converted when the preference is on)
/// ingredient lines — matching what the ingredients list, Cook Mode, and
/// "Add to Shopping List" (DUT-639) already show — rather than the recipe's
/// raw source-servings / imperial text. Before this fix, the "Share as Text"
/// menu item fed `RecipeShareTextFormatter.format(recipe:)` the untouched
/// `viewModel.recipe` directly, so a user who doubled the servings (or
/// enabled "Use Metric Units") and then shared would send a plain-text
/// recipe that silently disagreed with their own screen.
@Suite("RecipeDetailView.shareAsTextPayload")
struct RecipeDetailViewToolbarShareAsTextTests {

    @Test func scalesIngredientsByTheServingsFactor() {
        let recipe = RecipeDetailTestFixtures.makeRecipe(
            id: 1,
            withDetail: true,
            servings: 4,
            ingredients: [.init(text: "2 cups flour")]
        )

        let payload = RecipeDetailView.shareAsTextPayload(
            recipe: recipe,
            servingsScaleFactor: 2.0,
            useMetricUnits: false
        )

        #expect(payload.contains("4 cups flour"))
        #expect(!payload.contains("2 cups flour"))
    }

    @Test func convertsToMetricWhenThePreferenceIsOn() {
        let recipe = RecipeDetailTestFixtures.makeRecipe(
            id: 1,
            withDetail: true,
            servings: 1,
            ingredients: [.init(text: "1 cup milk")]
        )

        let payload = RecipeDetailView.shareAsTextPayload(
            recipe: recipe,
            servingsScaleFactor: 1.0,
            useMetricUnits: true
        )

        #expect(payload.contains("240 ml milk"))
        #expect(!payload.contains("1 cup milk"))
    }

    @Test func factorOneNoMetricPassesIngredientTextThroughUnchanged() {
        let recipe = RecipeDetailTestFixtures.makeRecipe(
            id: 1,
            withDetail: true,
            servings: 1,
            ingredients: [.init(text: "1 lb ground beef")]
        )

        let payload = RecipeDetailView.shareAsTextPayload(
            recipe: recipe,
            servingsScaleFactor: 1.0,
            useMetricUnits: false
        )

        #expect(payload.contains("1 lb ground beef"))
    }
}

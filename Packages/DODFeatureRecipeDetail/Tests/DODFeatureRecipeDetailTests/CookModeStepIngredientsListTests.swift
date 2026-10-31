import DODDomain
import DODSupport
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeStepIngredientsList") struct CookModeStepIngredientsListTests {

    @Test func displayTextScalesQuantity() {
        let list = CookModeStepIngredientsList(
            ingredients: [],
            scaleFactor: 2,
            useMetricUnits: false
        )
        let text = "1 cup flour"
        #expect(
            list.displayText(for: RecipeIngredient(text: text))
                == FractionRenderer.scale(text, by: 2)
        )
    }

    @Test func displayTextMatchesDrawerPipelineWhenMetric() {
        let list = CookModeStepIngredientsList(
            ingredients: [],
            scaleFactor: 1,
            useMetricUnits: true
        )
        let text = "1 cup flour"
        #expect(
            list.displayText(for: RecipeIngredient(text: text))
                == IngredientMetricConverter.metric(FractionRenderer.scale(text, by: 1))
        )
    }
}

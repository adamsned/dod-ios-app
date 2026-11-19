import DODDomain
import DODSupport
import Foundation

public enum TripSlotBuilder {
    /// Fallback yield when a recipe has no parsed `servings` (matches the detail screen's default of 4).
    static let defaultSourceServings = 4

    public static func makeSlot(
        day: Int,
        meal: Int,
        recipe: Recipe,
        constraints: TripPlanConstraints
    ) -> TripMealSlot {
        let source = max(1, recipe.servings ?? defaultSourceServings)
        let factor = Double(constraints.headcount) / Double(source)
        let charcoal = RecipeHeatProfile.derive(from: recipe).map {
            CharcoalRecipeConverter.recommend(
                ovenTempF: $0.ovenTempF,
                ovenDiameterInches: constraints.ovenDiameterInches,
                task: $0.task
            )
        }
        return TripMealSlot(
            day: day,
            meal: meal,
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            servings: constraints.headcount,
            scaleFactor: factor,
            charcoal: charcoal
        )
    }
}

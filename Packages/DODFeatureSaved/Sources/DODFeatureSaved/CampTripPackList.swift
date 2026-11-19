import DODSupport
import Foundation

/// DUT-1000 — turns a camp trip into rows for the existing Shopping / Bring List.
public enum CampTripPackList {

    /// One row per ingredient line across all meals in trip order, plus one
    /// fuel row for the whole-trip briquette total (when > 0).
    public static func rows(for trip: CampTrip) -> [ShoppingListViewModel.Item] {
        var rows: [ShoppingListViewModel.Item] = trip.sequencedMeals.flatMap { meal in
            meal.ingredients.map { line in
                ShoppingListViewModel.Item(
                    ingredientText: line,
                    recipeTitle: "Day \(meal.day + 1) · \(meal.recipeTitle)",
                    aisle: IngredientAisleClassifier.classify(line)
                )
            }
        }
        let total = CampFuelBudget.budget(for: trip).totalBriquettes
        if total > 0 {
            rows.append(
                ShoppingListViewModel.Item(
                    ingredientText: "\(total) charcoal briquettes",
                    recipeTitle: trip.name,
                    aisle: .other
                )
            )
        }
        return rows
    }
}

import DODSupport
import Foundation

// MARK: - Mock fixture (CL-82 — drives the view ahead of the entry surfaces)

// Split out of `ShoppingListViewModel.swift` so that file stays under SwiftLint's
// `file_length` cap once the derived-render-model caching landed — same split
// pattern already used for `ShoppingListViewModel+Dedup.swift`.
extension ShoppingListViewModel {

    /// Three recipes' worth of ingredient lines, classified through the live
    /// ``IngredientAisleClassifier``, so ``ShoppingListView`` is self-contained
    /// and previewable ahead of T-680c's entry wiring. The fixture deliberately
    /// includes a duplicate ("yellow onion" in two recipes) to demonstrate the
    /// per-recipe-row behavior (CL-77) and at least one `.other`-bucket line.
    /// Passes `store: nil` (DUT-488) so previews / snapshot fixtures never read
    /// or write the real App Group suite — the mock stays a pure in-memory list.
    public static var mock: ShoppingListViewModel {
        ShoppingListViewModel(items: mockItems, store: nil)
    }

    /// The mock rows as plain values (so tests can assert against them without
    /// reaching through the `@Observable` instance).
    public static var mockItems: [Item] {
        func rows(_ recipe: String, _ lines: [String]) -> [Item] {
            lines.map { line in
                Item(
                    ingredientText: line,
                    recipeTitle: recipe,
                    aisle: IngredientAisleClassifier.classify(line)
                )
            }
        }
        return rows(
            "Dutch Oven Pot Roast",
            [
                "3 lb beef chuck roast",
                "1 yellow onion, quartered",
                "4 carrots, peeled",
                "3 cloves garlic, minced",
                "2 cups beef broth",
                "1 tsp salt",
            ]
        )
            + rows(
                "Skillet Chicken Tacos",
                [
                    "1 lb chicken thighs",
                    "1 yellow onion, diced",
                    "2 limes",
                    "1 cup shredded cheddar",
                    "1 tsp cumin",
                    "8 corn tortillas",
                ]
            )
            + rows(
                "Weeknight Veggie Pasta",
                [
                    "12 oz pasta",
                    "2 zucchini, sliced",
                    "1 cup heavy cream",
                    "½ cup parmesan",
                    "2 tbsp olive oil",
                    "black pepper to taste",
                ]
            )
    }
}

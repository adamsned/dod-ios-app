import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the recipe-picker → shopping-list construction path
/// (US-39 / AC-39.3, CL-85). The `ShoppingListBuilderSheet` hands its selected
/// `[Recipe]` to `SavedView`, which builds a `ShoppingListViewModel(recipes:)`
/// (the T-680b convenience initializer). These tests pin that construction
/// step — the load-bearing logic behind the picker's "Build List" action —
/// since the SwiftUI selection state itself is exercised by the L4 snapshot /
/// in-app run. Constitution §6 L1.
@MainActor
@Suite("ShoppingListBuilderSheet construction (T-680c)") struct ShoppingListBuilderSheetTests {

    @Test func buildingFromSelectedRecipesExplodesIngredientsPerRecipe() {
        // Two recipes selected → every ingredient becomes one per-recipe row
        // (CL-77, no cross-recipe merge), classified through the live aisle map.
        let selected = [
            Self.recipe(id: 1, title: "Pot Roast", ingredients: ["3 lb beef chuck roast", "1 yellow onion"]),
            Self.recipe(id: 2, title: "Tacos", ingredients: ["1 lb chicken thighs"]),
        ]
        let viewModel = ShoppingListViewModel(recipes: selected)

        #expect(viewModel.items.count == 3)
        #expect(viewModel.items.map(\.recipeTitle) == ["Pot Roast", "Pot Roast", "Tacos"])
        #expect(!viewModel.isEmpty)
    }

    @Test func buildingFromASingleRecipeStillWorks() {
        // The picker enables "Build List" at ≥1 selection — one recipe is valid.
        let viewModel = ShoppingListViewModel(
            recipes: [Self.recipe(id: 1, title: "Solo", ingredients: ["2 limes", "1 tsp cumin"])]
        )
        #expect(viewModel.items.count == 2)
        // Classified across at least the produce + spices aisles.
        #expect(viewModel.sections.count >= 1)
    }

    @Test func duplicateIngredientsAcrossSelectedRecipesStayDistinct() {
        // CL-77 — three recipes calling for onion produce three rows, each
        // attributed to its source recipe (the v1 dedup rule).
        let viewModel = ShoppingListViewModel(recipes: [
            Self.recipe(id: 1, title: "A", ingredients: ["1 yellow onion"]),
            Self.recipe(id: 2, title: "B", ingredients: ["1 yellow onion"]),
            Self.recipe(id: 3, title: "C", ingredients: ["1 yellow onion"]),
        ])
        let produce = viewModel.sections.first { $0.aisle == .produce }
        #expect(produce?.items.count == 3)
        #expect(produce?.items.map(\.recipeTitle) == ["A", "B", "C"])
    }

    @Test func selectingARecipeWithNoIngredientsContributesNoRows() {
        // CL-85 — article-kind posts (empty ingredients) are still selectable
        // but add nothing to the list.
        let viewModel = ShoppingListViewModel(recipes: [
            Self.recipe(id: 1, title: "Article", ingredients: []),
            Self.recipe(id: 2, title: "Real", ingredients: ["2 limes"]),
        ])
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.recipeTitle == "Real")
    }

    // MARK: - Fixtures

    static func recipe(id: Int, title: String, ingredients: [String]) -> Recipe {
        Recipe(
            id: id,
            slug: "r\(id)",
            title: title,
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: ingredients.map { RecipeIngredient(text: $0) },
            instructions: [.init(step: 1, text: "Cook.")]
        )
    }
}

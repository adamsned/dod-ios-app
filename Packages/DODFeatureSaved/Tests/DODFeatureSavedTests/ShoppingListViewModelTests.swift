import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for ``ShoppingListViewModel`` — grouping, the ephemeral check
/// toggle, and the ephemeral "already have" toggle (CL-82 / US-39 AC-39.4 +
/// AC-39.5). Constitution §6 L1 mandate.
@MainActor
@Suite("ShoppingListViewModel (T-680b)") struct ShoppingListViewModelTests {

    // MARK: - Grouping

    @Test func emptyWhenNoItems() {
        let viewModel = ShoppingListViewModel(items: [])
        #expect(viewModel.isEmpty)
        #expect(viewModel.sections.isEmpty)
        #expect(viewModel.remainingCount == 0)
    }

    @Test func sectionsAreOrderedByStoreWalkAndOmitEmptyAisles() {
        let viewModel = ShoppingListViewModel(items: [
            Self.item("2 limes", "R", .produce),
            Self.item("1 tsp cumin", "R", .spices),
            Self.item("1 lb chicken", "R", .meat),
        ])
        // Only the three populated aisles render, in `Aisle.allCases` order
        // (produce → meat → ... → spices → other). Dairy / pantry / other are
        // omitted because they have zero rows (AC-39.4).
        #expect(viewModel.sections.map(\.aisle) == [.produce, .meat, .spices])
    }

    @Test func duplicateIngredientsFromDifferentRecipesStayAsSeparateRows() {
        // CL-77 — per-recipe rows, no cross-recipe merge.
        let viewModel = ShoppingListViewModel(items: [
            Self.item("1 yellow onion", "Pot Roast", .produce),
            Self.item("1 yellow onion", "Chicken Tacos", .produce),
        ])
        let produce = viewModel.sections.first { $0.aisle == .produce }
        #expect(produce?.items.count == 2)
        #expect(produce?.items.map(\.recipeTitle) == ["Pot Roast", "Chicken Tacos"])
    }

    @Test func mockFixtureClassifiesAcrossMultipleAisles() {
        let viewModel = ShoppingListViewModel.mock
        #expect(!viewModel.isEmpty)
        // The fixture spans at least produce, meat, dairy, pantry, spices.
        let aisles = Set(viewModel.sections.map(\.aisle))
        #expect(aisles.isSuperset(of: [.produce, .meat, .dairy, .pantry, .spices]))
        // 18 mock lines → 18 per-recipe rows (no merge).
        #expect(viewModel.items.count == 18)
    }

    @Test func builtFromRecipesExplodesIngredientsPerRecipe() {
        let recipes = [
            Self.recipe(id: 1, title: "A", ingredients: ["1 onion", "1 tsp salt"]),
            Self.recipe(id: 2, title: "B", ingredients: ["2 carrots"]),
        ]
        let viewModel = ShoppingListViewModel(recipes: recipes)
        #expect(viewModel.items.count == 3)
        #expect(viewModel.items.map(\.recipeTitle) == ["A", "A", "B"])
    }

    // MARK: - add(recipes:) — build / append in place (DUT-487 / T-906)

    @Test func addRecipesToEmptyModelPopulatesRows() {
        // Empty-first: a fresh `init()` model fills in place on the first add.
        let viewModel = ShoppingListViewModel()
        #expect(viewModel.isEmpty)

        viewModel.add(recipes: [
            Self.recipe(id: 1, title: "A", ingredients: ["1 onion", "1 tsp salt"])
        ])
        #expect(!viewModel.isEmpty)
        #expect(viewModel.items.count == 2)
        #expect(viewModel.items.map(\.recipeTitle) == ["A", "A"])
    }

    @Test func addRecipesAppendsAndKeepsExistingRows() {
        // Appending accumulates — existing rows are kept, new ones stack on
        // (no de-dup; per-recipe rows are intentional, CL-77).
        let viewModel = ShoppingListViewModel(recipes: [
            Self.recipe(id: 1, title: "A", ingredients: ["1 onion"])
        ])
        #expect(viewModel.items.count == 1)

        viewModel.add(recipes: [
            Self.recipe(id: 2, title: "B", ingredients: ["2 carrots", "1 lb chicken"])
        ])
        #expect(viewModel.items.count == 3)
        #expect(viewModel.items.map(\.recipeTitle) == ["A", "B", "B"])
    }

    @Test func addRecipesClassifiesAppendedRowsByAisle() {
        // Classification still applies to appended rows, so they land in the
        // right store-walk sections (AC-39.4).
        let viewModel = ShoppingListViewModel()
        viewModel.add(recipes: [
            Self.recipe(id: 1, title: "A", ingredients: ["1 lb chicken", "1 tsp cumin", "2 limes"])
        ])
        #expect(viewModel.sections.map(\.aisle) == [.produce, .meat, .spices])
    }

    @Test func addingSameRecipeTwiceStacksItsRows() {
        // Re-adding a recipe already on the list appends its rows again — no
        // cross-add de-dup (CL-77).
        let recipe = Self.recipe(id: 1, title: "A", ingredients: ["1 onion", "1 tsp salt"])
        let viewModel = ShoppingListViewModel(recipes: [recipe])
        viewModel.add(recipes: [recipe])
        #expect(viewModel.items.count == 4)
    }

    // MARK: - Check toggle (AC-39.5)

    @Test func toggleCheckedFlipsMembershipAndDecrementsUncheckedCount() {
        let item = Self.item("1 onion", "R", .produce)
        let viewModel = ShoppingListViewModel(items: [item])
        #expect(!viewModel.isChecked(item))
        #expect(viewModel.uncheckedCount == 1)

        viewModel.toggleChecked(item)
        #expect(viewModel.isChecked(item))
        #expect(viewModel.uncheckedCount == 0)
        // Checked rows stay visible (struck through), not removed.
        #expect(viewModel.remainingCount == 1)

        viewModel.toggleChecked(item)
        #expect(!viewModel.isChecked(item))
        #expect(viewModel.uncheckedCount == 1)
    }

    // MARK: - Already-have toggle (CL-82)

    @Test func markAlreadyHaveRemovesRowFromStillNeedList() {
        let keep = Self.item("1 onion", "R", .produce)
        let have = Self.item("1 tsp salt", "R", .spices)
        let viewModel = ShoppingListViewModel(items: [keep, have])
        #expect(viewModel.remainingCount == 2)

        viewModel.markAlreadyHave(have)
        #expect(viewModel.remainingCount == 1)
        #expect(viewModel.visibleItems.map(\.id) == [keep.id])
        // The spices section (only `have`) disappears entirely.
        #expect(viewModel.sections.map(\.aisle) == [.produce])
    }

    @Test func markingEveryRowAlreadyHaveYieldsEmptyState() {
        let item = Self.item("1 onion", "R", .produce)
        let viewModel = ShoppingListViewModel(items: [item])
        viewModel.markAlreadyHave(item)
        #expect(viewModel.isEmpty)
    }

    @Test func markAlreadyHaveClearsAnyCheckState() {
        let item = Self.item("1 onion", "R", .produce)
        let viewModel = ShoppingListViewModel(items: [item])
        viewModel.toggleChecked(item)
        #expect(viewModel.isChecked(item))
        viewModel.markAlreadyHave(item)
        #expect(!viewModel.checkedIDs.contains(item.id))
    }

    // MARK: - Fixtures

    static func item(
        _ text: String,
        _ recipe: String,
        _ aisle: IngredientAisleClassifier.Aisle
    ) -> ShoppingListViewModel.Item {
        ShoppingListViewModel.Item(ingredientText: text, recipeTitle: recipe, aisle: aisle)
    }

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

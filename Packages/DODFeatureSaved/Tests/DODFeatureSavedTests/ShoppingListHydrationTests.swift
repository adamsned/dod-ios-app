import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the DUT-487 shopping-list hydration fix. Saved recipes
/// returned by `RecipeStore.savedRecipes()` often carry EMPTY `ingredients`
/// (their detail was never fetched), so building the Shopping List straight
/// from them produced ZERO rows and the list stayed empty. The fix hydrates
/// each picked recipe through ``SavedDependencies/recipeWithIngredients(_:)``
/// before ``ShoppingListViewModel/add(recipes:)`` builds rows.
///
/// These tests exercise the seam the view drives: the hydrate closure
/// (`SavedView` passes `viewModel.recipeWithIngredients`) → the built list.
@MainActor
@Suite("Shopping list hydration (DUT-487)")
struct ShoppingListHydrationTests {

    /// The bug + fix: a saved recipe with EMPTY ingredients, hydrated first,
    /// yields a NON-empty list. Mirrors what `ShoppingListView.build(from:)`
    /// does — hydrate each recipe, then `add`.
    @Test func emptyIngredientsRecipeHydratesIntoNonEmptyList() async {
        let deps = StubSavedDependencies()
        // The store copy carries ingredients; the saved-list copy does not.
        deps.hydrated[42] = Self.recipe(id: 42, ingredients: ["2 cups flour", "1 tsp salt"])

        let empty = Self.recipe(id: 42, ingredients: [])
        #expect(empty.ingredients.isEmpty)

        let hydrated = await deps.recipeWithIngredients(empty)
        #expect(!hydrated.ingredients.isEmpty)

        let viewModel = ShoppingListViewModel()
        viewModel.add(recipes: [hydrated])
        #expect(!viewModel.isEmpty)
        #expect(viewModel.remainingCount == 2)
    }

    /// A recipe that ALREADY has ingredients is returned unchanged and is
    /// never routed through the fetch path (the stub records no hydrate call).
    @Test func alreadyHydratedRecipeIsReturnedUnchangedWithoutFetch() async {
        let deps = StubSavedDependencies()
        let full = Self.recipe(id: 7, ingredients: ["1 lb chicken"])

        let result = await deps.recipeWithIngredients(full)
        #expect(result == full)
        #expect(deps.fetchedIDs.isEmpty)  // no cache/network lookup happened
    }

    /// Defensive path: a recipe that can't be hydrated (the stub has no entry,
    /// modeling a fetch/parse failure or offline) comes back unchanged and
    /// simply contributes no rows — the same behavior as before the fix.
    @Test func unhydratableRecipeContributesNoRows() async {
        let deps = StubSavedDependencies()  // no `hydrated` entries
        let empty = Self.recipe(id: 99, ingredients: [])

        let result = await deps.recipeWithIngredients(empty)
        #expect(result == empty)

        let viewModel = ShoppingListViewModel()
        viewModel.add(recipes: [result])
        #expect(viewModel.isEmpty)
    }

    // MARK: - Fixtures

    static func recipe(id: Int, ingredients: [String]) -> Recipe {
        Recipe(
            id: id,
            slug: "s\(id)",
            title: "Title \(id)",
            excerpt: "Excerpt",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: ingredients.map { .init(text: $0) }
        )
    }
}

/// Stub `SavedDependencies` for the hydration tests. Models the live
/// `recipeWithIngredients` contract: a recipe that already has ingredients is
/// returned unchanged (no fetch); an empty one is looked up in `hydrated`
/// (keyed by id) — a hit returns the hydrated copy, a miss returns the recipe
/// unchanged (the defensive "can't hydrate" path).
@MainActor
final class StubSavedDependencies: SavedDependencies {
    /// Hydrated copies keyed by recipe id (the "store cache / fetch" result).
    var hydrated: [Int: Recipe] = [:]
    /// Ids the stub was asked to hydrate (empty-ingredient path only), so a
    /// test can assert an already-full recipe skipped the fetch.
    private(set) var fetchedIDs: [Int] = []

    nonisolated func savedRecipes() async throws -> [Recipe] { [] }

    func recipeWithIngredients(_ recipe: Recipe) async -> Recipe {
        guard recipe.ingredients.isEmpty else { return recipe }
        fetchedIDs.append(recipe.id)
        return hydrated[recipe.id] ?? recipe
    }
}

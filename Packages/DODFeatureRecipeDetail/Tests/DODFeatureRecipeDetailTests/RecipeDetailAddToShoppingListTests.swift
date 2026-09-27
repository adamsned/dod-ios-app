import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the DUT-534 Recipe-Detail "Add to Shopping List" action.
/// Detail carries a fully-loaded `recipe`, so the view model routes it straight
/// through the append seam and maps the result onto the Snackbar copy + action.
@MainActor
@Suite("Recipe Detail — Add to Shopping List (DUT-534)")
struct RecipeDetailAddToShoppingListTests {

    /// A successful append shows the count-aware success message AND a "View"
    /// action, and routes the already-loaded recipe through the seam (no fetch).
    @Test func successShowsMessageWithViewActionAndRoutesLoadedRecipe() async {
        let deps = FakeRecipeDetailDependencies()
        deps.addToShoppingListResult = .added(count: 3)
        let vm = Self.makeViewModel(deps: deps, ingredients: ["a", "b", "c"])

        await vm.addToShoppingList()

        #expect(vm.snackbarMessage == "Added 3 ingredients to your Shopping List")
        #expect(vm.snackbarActionTitle == "View")
        // The exact loaded recipe was routed through the seam.
        #expect(deps.addToShoppingListRecipes.count == 1)
        #expect(deps.addToShoppingListRecipes.first?.id == vm.recipe?.id)
    }

    /// The success message is singular for a one-ingredient recipe.
    @Test func singularIngredientMessage() {
        #expect(
            RecipeDetailViewModel.addedMessage(count: 1)
                == "Added 1 ingredient to your Shopping List"
        )
        #expect(
            RecipeDetailViewModel.addedMessage(count: 5)
                == "Added 5 ingredients to your Shopping List"
        )
    }

    /// A `.couldntLoad` result shows the recovery copy with NO action button.
    @Test func couldntLoadShowsRecoveryCopyWithoutAction() async {
        let deps = FakeRecipeDetailDependencies()
        deps.addToShoppingListResult = .couldntLoad
        let vm = Self.makeViewModel(deps: deps, ingredients: ["a"])

        await vm.addToShoppingList()

        #expect(vm.snackbarMessage == "Couldn't load ingredients. Open the recipe to add.")
        #expect(vm.snackbarActionTitle == nil)
    }

    /// No recipe loaded yet → `.couldntLoad` copy, and the seam is never called.
    @Test func noRecipeYetShortCircuitsToCouldntLoad() async {
        let deps = FakeRecipeDetailDependencies()
        let vm = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 1),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/1/") ?? URL(filePath: "/"),
            dependencies: deps
        )
        #expect(vm.recipe == nil)

        await vm.addToShoppingList()

        #expect(vm.snackbarMessage == "Couldn't load ingredients. Open the recipe to add.")
        #expect(deps.addToShoppingListRecipes.isEmpty)
    }

    /// `dismissSnackbar()` clears BOTH the message and the action title so a
    /// stale "View" can't linger onto a later message.
    @Test func dismissClearsMessageAndActionTitle() async {
        let deps = FakeRecipeDetailDependencies()
        deps.addToShoppingListResult = .added(count: 2)
        let vm = Self.makeViewModel(deps: deps, ingredients: ["a", "b"])

        await vm.addToShoppingList()
        #expect(vm.snackbarActionTitle == "View")

        vm.dismissSnackbar()
        #expect(vm.snackbarMessage == nil)
        #expect(vm.snackbarActionTitle == nil)
    }

    // MARK: - Fixtures

    static func makeViewModel(
        deps: FakeRecipeDetailDependencies,
        ingredients: [String]
    ) -> RecipeDetailViewModel {
        let vm = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 1),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/1/") ?? URL(filePath: "/"),
            dependencies: deps
        )
        vm.recipe = RecipeDetailTestFixtures.makeRecipe(
            id: 1,
            withDetail: true,
            ingredients: ingredients.map { .init(text: $0) }
        )
        return vm
    }
}

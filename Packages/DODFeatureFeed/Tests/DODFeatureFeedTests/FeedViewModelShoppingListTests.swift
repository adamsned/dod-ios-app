import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

// DUT-534 Part 2 — the Feed card "Add to Shopping List" quick-add flow: a
// `RecipeListItem` → minimal `Recipe` → appender append, mapped onto the
// confirmation snackbar. Uses `FakeFeedDependencies` (see `FeedViewModelTests`).

@MainActor
@Suite("FeedViewModel Add to Shopping List (DUT-534 Part 2)")
struct FeedViewModelShoppingListTests {

    private static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Excerpt \(id)",
            heroImage: URL(string: "https://example.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/recipe-\(id)/")
        )
    }

    @Test("Success maps to the added snackbar + View action")
    func successShowsAddedSnackbar() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .added(count: 3)
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.addToShoppingList(Self.makeItem(42))

        #expect(viewModel.shoppingListSnackbarMessage == "Added 3 ingredients to your Shopping List")
        #expect(viewModel.shoppingListSnackbarActionTitle == "View")
        // The card's identity flowed through as a minimal, ingredient-empty
        // recipe (the appender hydrates ingredients itself).
        #expect(dependencies.appendedRecipes.count == 1)
        #expect(dependencies.appendedRecipes.first?.id == 42)
        #expect(dependencies.appendedRecipes.first?.ingredients.isEmpty == true)
    }

    @Test("Singular ingredient copy is grammatical")
    func singularCopy() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .added(count: 1)
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.addToShoppingList(Self.makeItem(1))

        #expect(viewModel.shoppingListSnackbarMessage == "Added 1 ingredient to your Shopping List")
    }

    @Test("couldntLoad maps to the fallback copy with no action")
    func couldntLoadShowsFallback() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .couldntLoad
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.addToShoppingList(Self.makeItem(7))

        #expect(
            viewModel.shoppingListSnackbarMessage
                == "Couldn't load ingredients — open the recipe to add."
        )
        #expect(viewModel.shoppingListSnackbarActionTitle == nil)
    }

    @Test("Dismiss clears both the message and the action")
    func dismissClearsSnackbar() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .added(count: 2)
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.addToShoppingList(Self.makeItem(9))
        viewModel.dismissShoppingListSnackbar()

        #expect(viewModel.shoppingListSnackbarMessage == nil)
        #expect(viewModel.shoppingListSnackbarActionTitle == nil)
    }
}

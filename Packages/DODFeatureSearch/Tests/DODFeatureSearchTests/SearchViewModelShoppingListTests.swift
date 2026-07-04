import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

// DUT-534 Part 2 — the Search card "Add to Shopping List" quick-add flow: a
// `RecipeListItem` → minimal `Recipe` → appender append, mapped onto the
// confirmation snackbar. Uses `FakeSearchDependencies`.

@MainActor
@Suite("SearchViewModel Add to Shopping List (DUT-534 Part 2)")
struct SearchViewModelShoppingListTests {

    private static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Excerpt \(id)",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/recipe-\(id)/")
        )
    }

    private static func makeViewModel(_ dependencies: FakeSearchDependencies) -> SearchViewModel {
        let suiteName = "dod.searchShoppingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return SearchViewModel(
            dependencies: dependencies,
            recentSearches: RecentSearches(defaults: defaults, storageKey: "recents")
        )
    }

    @Test("Success maps to the added snackbar + View action")
    func successShowsAddedSnackbar() async {
        let dependencies = FakeSearchDependencies()
        dependencies.shoppingListResult = .added(count: 5)
        let viewModel = Self.makeViewModel(dependencies)

        await viewModel.addToShoppingList(Self.makeItem(11))

        #expect(viewModel.shoppingListSnackbarMessage == "Added 5 ingredients to your Shopping List")
        #expect(viewModel.shoppingListSnackbarActionTitle == "View")
        #expect(dependencies.appendedRecipes.count == 1)
        #expect(dependencies.appendedRecipes.first?.id == 11)
        #expect(dependencies.appendedRecipes.first?.ingredients.isEmpty == true)
    }

    @Test("Singular ingredient copy is grammatical")
    func singularCopy() async {
        let dependencies = FakeSearchDependencies()
        dependencies.shoppingListResult = .added(count: 1)
        let viewModel = Self.makeViewModel(dependencies)

        await viewModel.addToShoppingList(Self.makeItem(1))

        #expect(viewModel.shoppingListSnackbarMessage == "Added 1 ingredient to your Shopping List")
    }

    @Test("couldntLoad maps to the fallback copy with no action")
    func couldntLoadShowsFallback() async {
        let dependencies = FakeSearchDependencies()
        dependencies.shoppingListResult = .couldntLoad
        let viewModel = Self.makeViewModel(dependencies)

        await viewModel.addToShoppingList(Self.makeItem(3))

        #expect(
            viewModel.shoppingListSnackbarMessage
                == "Couldn't load ingredients — open the recipe to add."
        )
        #expect(viewModel.shoppingListSnackbarActionTitle == nil)
    }

    @Test("Dismiss clears both the message and the action")
    func dismissClearsSnackbar() async {
        let dependencies = FakeSearchDependencies()
        dependencies.shoppingListResult = .added(count: 2)
        let viewModel = Self.makeViewModel(dependencies)

        await viewModel.addToShoppingList(Self.makeItem(9))
        viewModel.dismissShoppingListSnackbar()

        #expect(viewModel.shoppingListSnackbarMessage == nil)
        #expect(viewModel.shoppingListSnackbarActionTitle == nil)
    }
}

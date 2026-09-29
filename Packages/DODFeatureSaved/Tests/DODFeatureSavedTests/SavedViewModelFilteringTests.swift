import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// DUT-1339 — the Saved-tab findability filters on ``SavedViewModel``: title
/// search, the type/state chips (Recipes / Articles / Downloaded), and their
/// composition with the collection shelf selection. All three narrow together.
@MainActor
@Suite("SavedViewModel findability filters (DUT-1339)") struct SavedViewModelFilteringTests {

    private func makeRecipe(id: Int, title: String, isArticle: Bool = false) -> Recipe {
        Recipe(
            id: id,
            slug: "s\(id)",
            title: title,
            excerpt: "Excerpt",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            kind: isArticle ? .article : .recipe
        )
    }

    private func loadedViewModel(
        recipes: [Recipe],
        downloaded: Set<Int> = [],
        desserts: Set<Int> = []
    ) async -> (SavedViewModel, FakeSavedDependencies) {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = recipes
        dependencies.downloadedIDs = downloaded
        dependencies.dessertIDs = desserts
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        return (viewModel, dependencies)
    }

    // MARK: - Search

    @Test func searchMatchesTitleCaseInsensitiveSubstring() async {
        let (viewModel, _) = await loadedViewModel(recipes: [
            makeRecipe(id: 1, title: "Dutch Oven Chili"),
            makeRecipe(id: 2, title: "Campfire Cornbread"),
            makeRecipe(id: 3, title: "Chicken and Rice"),
        ])

        viewModel.searchText = "ch"  // matches Chili, Cornbread(? no) -> substring in title
        // "ch" is a substring of "Chili" (Chi) and "Chicken"; NOT "Cornbread".
        #expect(viewModel.displayedRecipes.map(\.id) == [1, 3])

        viewModel.searchText = "CHICKEN"  // case-insensitive
        #expect(viewModel.displayedRecipes.map(\.id) == [3])

        viewModel.searchText = "   "  // whitespace-only clears the filter
        #expect(viewModel.displayedRecipes.map(\.id) == [1, 2, 3])
    }

    @Test func searchWithNoMatchYieldsEmptyAndFlagsFiltering() async {
        let (viewModel, _) = await loadedViewModel(recipes: [
            makeRecipe(id: 1, title: "Brisket")
        ])
        viewModel.searchText = "zzz"
        #expect(viewModel.displayedRecipes.isEmpty)
        #expect(viewModel.isFilteringActive)
    }

    // MARK: - Type partition (Recipes / Articles)

    @Test func typeFilterPartitionsRecipesAndArticles() async {
        let (viewModel, _) = await loadedViewModel(recipes: [
            makeRecipe(id: 1, title: "Stew", isArticle: false),
            makeRecipe(id: 2, title: "How to Season Cast Iron", isArticle: true),
            makeRecipe(id: 3, title: "Cobbler", isArticle: false),
        ])

        viewModel.typeFilter = .recipes
        #expect(viewModel.displayedRecipes.map(\.id) == [1, 3])

        viewModel.typeFilter = .articles
        #expect(viewModel.displayedRecipes.map(\.id) == [2])

        viewModel.typeFilter = .all
        #expect(viewModel.displayedRecipes.map(\.id) == [1, 2, 3])
        #expect(!viewModel.isFilteringActive)
    }

    // MARK: - Downloaded

    @Test func downloadedFilterKeepsOnlyDownloadedIDs() async {
        let (viewModel, _) = await loadedViewModel(
            recipes: [
                makeRecipe(id: 1, title: "A"),
                makeRecipe(id: 2, title: "B"),
                makeRecipe(id: 3, title: "C"),
            ],
            downloaded: [2, 3]
        )
        // Sanity: the view model hydrated its download set from the dependency.
        #expect(viewModel.downloadedIDs == [2, 3])

        viewModel.typeFilter = .downloaded
        #expect(viewModel.displayedRecipes.map(\.id) == [2, 3])
    }

    // MARK: - Desserts (DUT-1339 / DUT-325)

    @Test func dessertFilterKeepsOnlyDessertIDs() async {
        let (viewModel, _) = await loadedViewModel(
            recipes: [
                makeRecipe(id: 1, title: "Chili"),
                makeRecipe(id: 2, title: "Skillet Brownie"),
                makeRecipe(id: 3, title: "Peach Cobbler"),
            ],
            desserts: [2, 3]
        )
        // Sanity: the view model hydrated its dessert set from the dependency.
        #expect(viewModel.dessertIDs == [2, 3])

        viewModel.typeFilter = .desserts
        #expect(viewModel.displayedRecipes.map(\.id) == [2, 3])
        #expect(viewModel.isFilteringActive)
    }

    // MARK: - Composition

    @Test func searchComposesWithTypeFilter() async {
        let (viewModel, _) = await loadedViewModel(recipes: [
            makeRecipe(id: 1, title: "Chili Recipe", isArticle: false),
            makeRecipe(id: 2, title: "Chili Article", isArticle: true),
            makeRecipe(id: 3, title: "Stew", isArticle: false),
        ])
        viewModel.searchText = "chili"
        viewModel.typeFilter = .recipes
        // "chili" narrows to 1 & 2, then Recipes drops the article (2).
        #expect(viewModel.displayedRecipes.map(\.id) == [1])
    }

    @Test func filtersComposeWithCollectionSelection() async {
        let (viewModel, _) = await loadedViewModel(recipes: [
            makeRecipe(id: 1, title: "Chili", isArticle: false),
            makeRecipe(id: 2, title: "Chicken", isArticle: false),
            makeRecipe(id: 3, title: "Cast Iron Care", isArticle: true),
        ])
        await viewModel.addCollection(name: "Dinner")
        let dinner = viewModel.collections[0]
        // Dinner holds the two recipes and the article.
        await viewModel.setCollections(forRecipe: 1, to: [dinner.id])
        await viewModel.setCollections(forRecipe: 3, to: [dinner.id])
        viewModel.selectCollection(dinner.id)

        // Collection scope = {1, 3}; the Recipes filter drops the article (3).
        viewModel.typeFilter = .recipes
        #expect(viewModel.displayedRecipes.map(\.id) == [1])

        // Now search within the collection scope for a title the member has.
        viewModel.typeFilter = .all
        viewModel.searchText = "chili"
        #expect(viewModel.displayedRecipes.map(\.id) == [1])

        // A title that exists in the saved set but NOT in this collection stays hidden.
        viewModel.searchText = "chicken"
        #expect(viewModel.displayedRecipes.isEmpty)
    }
}

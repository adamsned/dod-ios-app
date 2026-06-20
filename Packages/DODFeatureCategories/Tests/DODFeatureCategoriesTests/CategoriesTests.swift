import DODDomain
import Foundation
import Testing

@testable import DODFeatureCategories

// T-800 (CL-194): the `CategoryListViewModelTests` + `CategoryListSearchFilterTests`
// suites were removed alongside `CategoryListView` / `CategoryListViewModel`
// when the Categories tab was folded into Search (its browse list now lives
// in the Search idle view, CL-193). `CategoryRecipesView` + its view model
// stay — they back the category-recipes screen the Search browse rows push.

@MainActor
@Suite("CategoryRecipesViewModel (T-091, T-092)") struct CategoryRecipesViewModelTests {

    @Test func initialLoadFromCategoryPage() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(Self.makeItem)
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.count == 5)
        #expect(viewModel.loadState == .loaded)
    }

    @Test func emptyPageShowsEmptyState() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = []
        let category = DODDomain.Category(id: 1, name: "Z", slug: "z", count: 0)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .empty)
    }

    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "R\(id)",
            excerpt: "e",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}

final class FakeCategoriesDependencies: CategoriesDependencies, @unchecked Sendable {
    var categories: [DODDomain.Category] = []
    var posts: [Int: [RecipeListItem]] = [:]
    var fetchShouldFail = false

    func fetchCategories() async throws -> [DODDomain.Category] {
        if fetchShouldFail { throw URLError(.notConnectedToInternet) }
        return categories
    }

    func fetchPosts(categoryID: Int, page: Int) async throws -> [RecipeListItem] {
        posts[page] ?? []
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        let allPagedItems = posts.values.flatMap { $0 }
        let byID = Dictionary(grouping: allPagedItems, by: \.id).mapValues { $0.first }
        return ids.compactMap { byID[$0].flatMap { $0 } }
    }
}

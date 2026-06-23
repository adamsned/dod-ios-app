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

    @Test func shortMidListPageKeepsPaging() async throws {
        // DUT-265: page 2 returns fewer than a full batch, but X-WP-TotalPages
        // says there are 3 pages — pagination must continue to page 3 instead of
        // latching on the short page (the same bug DUT-237 fixed for the Feed).
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...20).map(Self.makeItem)
        dependencies.posts[2] = (21...35).map(Self.makeItem)  // short page (15 items)
        dependencies.posts[3] = (36...55).map(Self.makeItem)
        dependencies.totalPagesOverride = 3
        let category = DODDomain.Category(id: 9, name: "Big", slug: "big", count: 55)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()

        var last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)  // -> page 2 (short)
        #expect(viewModel.items.count == 35)

        last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)  // -> page 3 (never ran pre-fix)
        #expect(viewModel.items.count == 55)
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
    /// DUT-265: override the reported `X-WP-TotalPages`. When nil, derived from
    /// the highest seeded page (a short final page still ends pagination).
    var totalPagesOverride: Int?

    func fetchCategories() async throws -> [DODDomain.Category] {
        if fetchShouldFail { throw URLError(.notConnectedToInternet) }
        return categories
    }

    func fetchPosts(
        categoryID: Int,
        page: Int
    ) async throws -> (items: [RecipeListItem], totalPages: Int) {
        let totalPages = totalPagesOverride ?? max(posts.keys.max() ?? 1, 1)
        return (posts[page] ?? [], totalPages)
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        let allPagedItems = posts.values.flatMap { $0 }
        let byID = Dictionary(grouping: allPagedItems, by: \.id).mapValues { $0.first }
        return ids.compactMap { byID[$0].flatMap { $0 } }
    }
}

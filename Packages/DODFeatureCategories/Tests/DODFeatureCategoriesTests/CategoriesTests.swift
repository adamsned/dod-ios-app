import DODDomain
import Foundation
import Testing

@testable import DODFeatureCategories

@MainActor
@Suite("CategoryListViewModel (T-090, T-092)") struct CategoryListViewModelTests {

    @Test func successfulLoadPopulatesCategories() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.categories = [
            .init(id: 1, name: "Beef", slug: "beef", count: 10),
            .init(id: 2, name: "Desserts", slug: "desserts", count: 22),
        ]
        let viewModel = CategoryListViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.categories.count == 2)
        #expect(viewModel.loadState == .loaded)
    }

    @Test func failureProducesErrorStateAndRetryWorks() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.fetchShouldFail = true
        let viewModel = CategoryListViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .error)
        dependencies.fetchShouldFail = false
        dependencies.categories = [.init(id: 1, name: "X", slug: "x", count: 1)]
        await viewModel.retry()
        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.categories.count == 1)
    }
}

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

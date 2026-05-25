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
@Suite("CategoryListView search filter (T-340 / AC-19.3)") struct CategoryListSearchFilterTests {

    @Test func emptyQueryReturnsFullList() {
        let categories = Self.makeCategories()
        let result = CategoryListView.filtered(categories: categories, matching: "")
        #expect(result.count == categories.count)
    }

    @Test func whitespaceQueryReturnsFullList() {
        let categories = Self.makeCategories()
        let result = CategoryListView.filtered(categories: categories, matching: "   \n\t")
        #expect(result.count == categories.count)
    }

    @Test func substringMatchIsCaseInsensitive() {
        let categories = Self.makeCategories()
        let lowercased = CategoryListView.filtered(categories: categories, matching: "beef")
        let uppercased = CategoryListView.filtered(categories: categories, matching: "BEEF")
        let mixed = CategoryListView.filtered(categories: categories, matching: "BeEf")
        #expect(lowercased.map(\.id) == [1])
        #expect(uppercased.map(\.id) == [1])
        #expect(mixed.map(\.id) == [1])
    }

    @Test func substringMatchMatchesAnywhereInName() {
        let categories = Self.makeCategories()
        // "ast" appears inside "Breakfast" and inside "Pasta" — substring
        // match should pick both, in input order.
        let astMatches = CategoryListView.filtered(categories: categories, matching: "ast")
        #expect(astMatches.map(\.name) == ["Breakfast", "Pasta"])
        // Prefix-only match.
        let oneSubstring = CategoryListView.filtered(categories: categories, matching: "one")
        #expect(oneSubstring.map(\.name) == ["One-pot meals"])
    }

    @Test func noMatchReturnsEmpty() {
        let categories = Self.makeCategories()
        let result = CategoryListView.filtered(categories: categories, matching: "zzz-nope")
        #expect(result.isEmpty)
    }

    @Test func queryPreservesOrderOfInput() {
        let categories = Self.makeCategories()
        // 's' matches multiple; filter should preserve input order.
        let result = CategoryListView.filtered(categories: categories, matching: "s")
        let matchingIDs = categories.filter { $0.name.localizedCaseInsensitiveContains("s") }.map(\.id)
        #expect(result.map(\.id) == matchingIDs)
    }

    static func makeCategories() -> [DODDomain.Category] {
        [
            .init(id: 1, name: "Beef", slug: "beef", count: 42),
            .init(id: 2, name: "Breakfast", slug: "breakfast", count: 28),
            .init(id: 3, name: "Chicken", slug: "chicken", count: 56),
            .init(id: 4, name: "Desserts", slug: "desserts", count: 33),
            .init(id: 5, name: "One-pot meals", slug: "one-pot", count: 19),
            .init(id: 6, name: "Pasta", slug: "pasta", count: 24),
            .init(id: 7, name: "Sides", slug: "sides", count: 18),
            .init(id: 8, name: "Soups & stews", slug: "soups", count: 22),
        ]
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

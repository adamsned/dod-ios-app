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

    @Test func appendFailureKeepsTheLoadedGrid() async throws {
        // DUT-282: a transient loadMore (append) failure must keep the
        // already-loaded grid + the `.loaded` state, not wipe it to a full-screen
        // error or reset pagination (mirrors the Feed's DUT-223 contract).
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...20).map(Self.makeItem)
        dependencies.totalPagesOverride = 3
        dependencies.failOnPage = 2
        let category = DODDomain.Category(id: 9, name: "Big", slug: "big", count: 60)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.count == 20)
        #expect(viewModel.loadState == .loaded)

        let last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)  // -> page 2 throws
        #expect(viewModel.items.count == 20)  // grid preserved, not wiped
        #expect(viewModel.loadState == .loaded)  // NOT .error
    }

    @Test func refreshReloadsPageOneAndBumpsHapticCount() async {
        // DUT-693 (PR6): pull-to-refresh reloads page 1 and bumps `refreshCount`
        // (the `.success` haptic trigger) on a clean reload.
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(Self.makeItem)
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.refreshCount == 0)

        // Category now returns a different set — refresh replaces page 1.
        dependencies.posts[1] = (10...16).map(Self.makeItem)
        await viewModel.refresh()
        #expect(viewModel.items.count == 7)
        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.refreshCount == 1)
    }

    @Test func refreshFailureKeepsTheLoadedGrid() async {
        // DUT-693 (PR6): a failed pull-to-refresh on a populated grid keeps the
        // items + `.loaded` state (no wipe to the error screen) and does NOT
        // reward a `.success` haptic.
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(Self.makeItem)
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()

        dependencies.failOnPage = 1
        await viewModel.refresh()
        #expect(viewModel.items.count == 5)  // grid preserved
        #expect(viewModel.loadState == .loaded)  // NOT .error
        #expect(viewModel.refreshCount == 0)  // no reward on failure
    }

    @Test func saveToggleCountFiresOnlyOnGenuineToggleNotOnAppearOrRefresh() async {
        // DUT-697: the `.selection` save haptic must fire ONLY on a genuine
        // long-press Save/Unsave — never on appear/refresh reconciliation of the
        // saved-id set (which reassigns `savedRecipeIDs` and previously drove the
        // haptic directly, mis-firing on first appear + every pull-to-refresh).
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(Self.makeItem)
        dependencies.savedIDs = [1, 3]  // a populated set to reconcile on appear
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)

        // Appear hydrates the (non-empty) saved set but must not fire the haptic.
        await viewModel.onAppear()
        #expect(viewModel.savedRecipeIDs == [1, 3])
        #expect(viewModel.saveToggleCount == 0)

        // A pull-to-refresh (even one that picks up an out-of-band save) must not
        // fire the save haptic either.
        dependencies.savedIDs = [1, 3, 5]
        await viewModel.refresh()
        #expect(viewModel.savedRecipeIDs == [1, 3, 5])
        #expect(viewModel.saveToggleCount == 0)

        // Only a genuine user toggle bumps the count.
        viewModel.applyOptimisticSaveToggle(id: 5)  // unsave
        #expect(viewModel.saveToggleCount == 1)
        viewModel.applyOptimisticSaveToggle(id: 2)  // save
        #expect(viewModel.saveToggleCount == 2)
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
    /// DUT-282: make `fetchPosts` throw for this page (to exercise a loadMore
    /// failure on a specific append).
    var failOnPage: Int?

    func fetchCategories() async throws -> [DODDomain.Category] {
        if fetchShouldFail { throw URLError(.notConnectedToInternet) }
        return categories
    }

    func fetchPosts(
        categoryID: Int,
        page: Int
    ) async throws -> (items: [RecipeListItem], totalPages: Int) {
        if page == failOnPage { throw URLError(.notConnectedToInternet) }
        let totalPages = totalPagesOverride ?? max(posts.keys.max() ?? 1, 1)
        return (posts[page] ?? [], totalPages)
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        let allPagedItems = posts.values.flatMap { $0 }
        let byID = Dictionary(grouping: allPagedItems, by: \.id).mapValues { $0.first }
        return ids.compactMap { byID[$0].flatMap { $0 } }
    }

    /// DUT-697: the saved-id set the VM hydrates on appear/refresh (defaults to
    /// empty via the protocol extension; overridden here to exercise a populated
    /// reconciliation that must NOT fire the save haptic).
    var savedIDs: Set<Int> = []
    func savedRecipeIDs() async throws -> Set<Int> { savedIDs }
}

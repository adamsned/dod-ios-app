import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite("FeedViewModel (T-081, T-086)") struct FeedViewModelTests {

    @Test func initialLoadPopulatesItems() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.count == 20)
        #expect(viewModel.loadState == .loaded)
    }

    @Test func loadMoreAppendsNextPage() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        dependencies.pages[2] = (21...40).map(Self.makeItem)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        let last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)
        #expect(viewModel.items.count == 40)
    }

    @Test func shortMidListPageDoesNotStopPagination() async throws {
        // DUT-237: page 2 returns fewer than a full batch, but X-WP-TotalPages
        // says there are 3 pages — pagination must continue to page 3 instead
        // of latching "reached end" on the short page (the bug that stopped the
        // feed at "Roasted Cauliflower Steaks").
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        dependencies.pages[2] = (21...35).map(Self.makeItem)  // short page (15 items)
        dependencies.pages[3] = (36...55).map(Self.makeItem)
        dependencies.totalPagesOverride = 3
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        var last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)  // -> page 2 (short)
        #expect(viewModel.items.count == 35)

        last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)  // -> page 3 (never ran pre-fix)
        #expect(viewModel.items.count == 55)
    }

    @Test func transientLoadMoreFailureDoesNotLatchReachedEnd() async throws {
        // DUT-237 / DUT-223: a transient tail-pagination failure must not
        // permanently kill infinite scroll — a later near-bottom appearance
        // resumes instead of being stuck for the whole session.
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        dependencies.pages[2] = (21...40).map(Self.makeItem)
        dependencies.totalPagesOverride = 3  // more pages exist
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()

        // Page-2 fetch blips.
        dependencies.shouldFail = true
        var last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)
        #expect(viewModel.items.count == 20, "a failed page must keep what we have")

        // Network recovers — the next attempt retries and loads.
        dependencies.shouldFail = false
        last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)
        #expect(viewModel.items.count == 40, "pagination must resume after a transient failure")
    }

    @Test func firstLaunchOfflineShowsEmptyState() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.shouldFail = true
        dependencies.online = false
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .firstLaunchOffline)
    }

    @Test func refreshClearsBlocklistAndReloads() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...3).map(Self.makeItem)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(dependencies.clearBlocklistCalls == 0)
        await viewModel.refresh()
        #expect(dependencies.clearBlocklistCalls == 1)
        #expect(viewModel.items.count == 3)
    }

    @Test func blocklistedItemsAreFilteredByCacheLayer() async throws {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...3).map(Self.makeItem)
        // Simulate blocklist: item id=2 absent from cache reads.
        dependencies.blocklistedIDs.insert(2)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.map(\.id) == [1, 3])
    }

    @Test func onAppearHydratesSavedIDsAndOptimisticToggleFlips() async throws {
        // T-765 / CL-162 (DUT-71) — the card long-press menu reads
        // `savedRecipeIDs`. It hydrates from the store on appear, and an
        // optimistic toggle flips membership immediately (so the menu label is
        // correct on re-open) ahead of the async store round-trip.
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...3).map(Self.makeItem)
        dependencies.savedIDs = [2]
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.savedRecipeIDs == [2])

        // Save an unsaved card + unsave the saved card — both flip locally.
        viewModel.applyOptimisticSaveToggle(id: 1)
        viewModel.applyOptimisticSaveToggle(id: 2)
        #expect(viewModel.savedRecipeIDs == [1])
    }

    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Excerpt \(id)",
            heroImage: URL(string: "https://example.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}

// MARK: - Fake dependencies

final class FakeFeedDependencies: FeedDependencies, @unchecked Sendable {
    var pages: [Int: [RecipeListItem]] = [:]
    var blocklistedIDs: Set<Int> = []
    var shouldFail: Bool = false
    var online: Bool = true
    var clearBlocklistCalls: Int = 0
    var savedIDs: Set<Int> = []
    /// DUT-237: override the reported `X-WP-TotalPages`. When nil, it derives
    /// from the highest page index that has data, so a short final page still
    /// ends pagination (matching the pre-DUT-237 `< 20` heuristic for tests
    /// that predate this).
    var totalPagesOverride: Int?

    func fetchPosts(page: Int) async throws -> (items: [RecipeListItem], totalPages: Int) {
        if shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        let totalPages = totalPagesOverride ?? max(pages.keys.max() ?? 1, 1)
        return (pages[page] ?? [], totalPages)
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        let allPagedItems = pages.values.flatMap { $0 }
        let byID = Dictionary(grouping: allPagedItems, by: \.id).mapValues { $0.first }
        return ids.compactMap { id in
            guard !blocklistedIDs.contains(id) else { return nil }
            return byID[id].flatMap { $0 }
        }
    }

    func cachedListPage(key: String) async throws -> [Int]? { nil }
    func saveListPage(key: String, page: Int, recipeIDs: [Int]) async throws {}

    func clearBlocklist() async throws { clearBlocklistCalls += 1 }
    func isOnline() async -> Bool { online }
    func connectivityChanges() async -> AsyncStream<Bool> {
        AsyncStream { _ in }
    }
    func savedRecipeIDs() async throws -> Set<Int> { savedIDs }
}

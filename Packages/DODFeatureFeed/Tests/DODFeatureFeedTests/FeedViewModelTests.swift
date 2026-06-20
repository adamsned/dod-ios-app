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

    @Test func loadMoreKeepsAlreadyLoadedRowsWhenCacheEvictsThem() async throws {
        // DUT-99 — the old loadMore re-read the full id list from the cache and
        // REPLACED `items`. Once the LRU cache evicted an earlier row, that
        // re-query silently dropped it (compactMap), so the feed shrank/jumped
        // mid-scroll. Append-only keeps already-loaded rows regardless of the
        // cache's later state.
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...20).map(Self.makeItem)
        dependencies.pages[2] = (21...40).map(Self.makeItem)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.items.count == 20)

        // Simulate the cache evicting the top-of-feed row (id=1) before page 2.
        dependencies.blocklistedIDs.insert(1)
        let last = try #require(viewModel.items.last)
        await viewModel.loadMoreIfNeeded(currentItem: last)

        // id=1 is still shown (not dropped), the full page-2 appended, order kept.
        #expect(viewModel.items.count == 40)
        #expect(viewModel.items.first?.id == 1)
        #expect(viewModel.items.map(\.id) == Array(1...40))
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

    func fetchPosts(page: Int) async throws -> [RecipeListItem] {
        if shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        return pages[page] ?? []
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

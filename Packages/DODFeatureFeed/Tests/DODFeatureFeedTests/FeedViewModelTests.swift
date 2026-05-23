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
}

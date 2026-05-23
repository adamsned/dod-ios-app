import DODDomain
import DODNetworking
import DODPersistence
import Foundation

/// Narrow surface the Feed feature needs from external modules. Lets us
/// swap real `WPRestClient` for a fake in unit tests without touching the
/// view-model API.
public protocol FeedDependencies: Sendable {
    func fetchPosts(page: Int) async throws -> [RecipeListItem]
    func cache(listItems: [RecipeListItem]) async throws
    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem]
    func cachedListPage(key: String) async throws -> [Int]?
    func saveListPage(key: String, page: Int, recipeIDs: [Int]) async throws
    func clearBlocklist() async throws
    func isOnline() async -> Bool
    func connectivityChanges() async -> AsyncStream<Bool>
}

/// Production wiring. Constructed by the app composition root (T-140).
public struct LiveFeedDependencies: FeedDependencies {

    let client: WPRestClient
    let store: RecipeStore
    let monitor: NetworkMonitor

    public init(client: WPRestClient, store: RecipeStore, monitor: NetworkMonitor) {
        self.client = client
        self.store = store
        self.monitor = monitor
    }

    public func fetchPosts(page: Int) async throws -> [RecipeListItem] {
        try await client.posts(page: page)
    }

    public func cache(listItems: [RecipeListItem]) async throws {
        try await store.cache(listItems: listItems)
    }

    public func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        try await store.listItems(forIDs: ids)
    }

    public func cachedListPage(key: String) async throws -> [Int]? {
        // T-081 reads from CachedListPage; for simplicity in v1 we don't
        // populate it from this feature and return nil. Hydration will come
        // from CachedRecipe directly in T-083.
        nil
    }

    public func saveListPage(key: String, page: Int, recipeIDs: [Int]) async throws {
        // No-op for v1 — see cachedListPage(key:) note above.
    }

    public func clearBlocklist() async throws {
        try await store.clearBlocklist()
    }

    public func isOnline() async -> Bool {
        await monitor.isOnline
    }

    public func connectivityChanges() async -> AsyncStream<Bool> {
        await monitor.changes()
    }
}

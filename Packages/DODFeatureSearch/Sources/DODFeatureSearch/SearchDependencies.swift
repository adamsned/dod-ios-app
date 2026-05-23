import DODAnalytics
import DODDomain
import DODNetworking
import DODPersistence
import Foundation

public protocol SearchDependencies: Sendable {
    func search(query: String) async throws -> [RecipeListItem]
    func cache(listItems: [RecipeListItem]) async throws
    func sendSearchTelemetry(queryHash: String) async
    func isOnline() async -> Bool
}

public struct LiveSearchDependencies: SearchDependencies {
    let client: WPRestClient
    let store: RecipeStore
    let monitor: NetworkMonitor

    public init(client: WPRestClient, store: RecipeStore, monitor: NetworkMonitor) {
        self.client = client
        self.store = store
        self.monitor = monitor
    }

    public func search(query: String) async throws -> [RecipeListItem] {
        try await client.search(query: query)
    }

    public func cache(listItems: [RecipeListItem]) async throws {
        try await store.cache(listItems: listItems)
    }

    public func sendSearchTelemetry(queryHash: String) async {
        Telemetry.shared.send(.recipeSearched(queryHash: queryHash))
    }

    public func isOnline() async -> Bool {
        await monitor.isOnline
    }
}

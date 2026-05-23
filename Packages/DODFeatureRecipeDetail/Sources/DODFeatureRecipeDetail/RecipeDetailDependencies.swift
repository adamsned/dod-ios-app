import DODAnalytics
import DODDomain
import DODNetworking
import DODPersistence
import Foundation

/// Surface needed by recipe detail. Production wires to the hybrid REST +
/// JSON-LD fetch path; tests pass a fake.
public protocol RecipeDetailDependencies: Sendable {
    func cachedRecipe(id: Int) async throws -> Recipe?
    func fetchHTML(for url: URL) async throws -> String
    func parseJSONLD(html: String, merging: RecipeListItem, canonicalURL: URL) throws -> Recipe
    func relatedRecipes(forCategoryID: Int) async throws -> [RecipeListItem]
    func mergeDetail(_ recipe: Recipe) async throws
    func markJSONLDFailed(id: Int) async throws
    func isSaved(id: Int) async throws -> Bool
    func toggleSaved(id: Int) async throws -> Bool
    func isOnline() async -> Bool
    func sendTelemetry(_ event: AnalyticsEvent) async
}

public struct LiveRecipeDetailDependencies: RecipeDetailDependencies {

    let client: WPRestClient
    let fetcher: RecipePageFetcher
    let store: RecipeStore
    let monitor: NetworkMonitor

    public init(
        client: WPRestClient,
        fetcher: RecipePageFetcher,
        store: RecipeStore,
        monitor: NetworkMonitor
    ) {
        self.client = client
        self.fetcher = fetcher
        self.store = store
        self.monitor = monitor
    }

    public func cachedRecipe(id: Int) async throws -> Recipe? {
        try await store.recipe(id: id)
    }

    public func fetchHTML(for url: URL) async throws -> String {
        try await fetcher.html(for: url)
    }

    public func parseJSONLD(html: String, merging: RecipeListItem, canonicalURL: URL) throws -> Recipe {
        try JSONLDRecipeParser.parse(html: html, merging: merging, canonicalURL: canonicalURL)
    }

    public func relatedRecipes(forCategoryID categoryID: Int) async throws -> [RecipeListItem] {
        let items = try await client.posts(categoryID: categoryID, page: 1, perPage: 5)
        return Array(items.prefix(4))
    }

    public func mergeDetail(_ recipe: Recipe) async throws {
        try await store.mergeDetail(recipe)
    }

    public func markJSONLDFailed(id: Int) async throws {
        try await store.markJSONLDFailed(id: id)
    }

    public func isSaved(id: Int) async throws -> Bool {
        try await store.isSaved(id: id)
    }

    public func toggleSaved(id: Int) async throws -> Bool {
        try await store.toggleSaved(id: id)
    }

    public func isOnline() async -> Bool {
        await monitor.isOnline
    }

    public func sendTelemetry(_ event: AnalyticsEvent) async {
        Telemetry.shared.send(event)
    }
}

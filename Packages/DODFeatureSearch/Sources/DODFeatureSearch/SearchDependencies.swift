import DODAnalytics
import DODDomain
import DODNetworking
import DODPersistence
import Foundation

/// Surface area Search needs from the rest of the app. The protocol exists so
/// view-model tests can swap a deterministic fake in; LiveSearchDependencies
/// is the production wiring.
///
/// Spec trace: US-12 / AC-12.1..AC-12.4 (ingredient index, filter chips,
/// recent history, empty-state suggestions).
public protocol SearchDependencies: Sendable {
    // MARK: - REST + local search
    func search(query: String) async throws -> [RecipeListItem]
    /// Recipe IDs whose locally-indexed ingredients contain `query`.
    /// Empty array is the normal "nothing matched" return — not an error.
    func searchIngredients(matching query: String) async throws -> [Int]
    /// Hydrate `[RecipeListItem]` from the local cache for the given IDs.
    /// Returns items in the same order as `ids`; missing/blocklisted IDs are
    /// silently skipped.
    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem]
    func cache(listItems: [RecipeListItem]) async throws

    // MARK: - Filter post-processing inputs
    /// `recipeID -> [WP category IDs]` map for the result set. Used by
    /// SearchFilters when the user picks a category chip.
    func categoryIDs(forRecipeIDs ids: [Int]) async throws -> [Int: [Int]]
    /// `recipeID -> total time in seconds` map. Sourced from the local
    /// detail cache; recipes never opened return absent → cook-time filter
    /// excludes them, which matches the spec's "filter ignorance defaults
    /// to MISS" rule.
    func totalSeconds(forRecipeIDs ids: [Int]) async throws -> [Int: Int]
    /// Set of recipe IDs the user has opened (any cached row). Drives the
    /// "Recently viewed" filter chip.
    func recentlyViewedRecipeIDs() async throws -> Set<Int>

    // MARK: - Filter chip data + empty-state suggestions
    /// All WP categories, alphabetized. Empty array on REST failure — the
    /// chip simply hides "All categories" submenu options rather than
    /// surfacing an error to the user during search.
    func allCategories() async throws -> [DODDomain.Category]

    // MARK: - Telemetry + connectivity
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

    public func searchIngredients(matching query: String) async throws -> [Int] {
        try await store.searchIngredients(matching: query)
    }

    public func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        try await store.listItems(forIDs: ids)
    }

    public func cache(listItems: [RecipeListItem]) async throws {
        try await store.cache(listItems: listItems)
    }

    public func categoryIDs(forRecipeIDs ids: [Int]) async throws -> [Int: [Int]] {
        try await store.categoryIDs(forRecipeIDs: ids)
    }

    public func totalSeconds(forRecipeIDs ids: [Int]) async throws -> [Int: Int] {
        try await store.totalSeconds(forRecipeIDs: ids)
    }

    public func recentlyViewedRecipeIDs() async throws -> Set<Int> {
        try await store.recentlyViewedRecipeIDs()
    }

    public func allCategories() async throws -> [DODDomain.Category] {
        try await client.categories()
    }

    public func sendSearchTelemetry(queryHash: String) async {
        Telemetry.shared.send(.recipeSearched(queryHash: queryHash))
    }

    public func isOnline() async -> Bool {
        await monitor.isOnline
    }
}

import DODAnalytics
import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
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
    /// US-12 / AC-12.3 amendment / CL-106 (T-637): network-side companion to
    /// `totalSeconds(forRecipeIDs:)`. Fetches each recipe's rendered HTML
    /// page and pulls the JSON-LD `totalTime` ISO-8601 duration so the
    /// cook-time filter narrows uncached results (the pre-fix path
    /// populated `lastTotalSecondsByRecipe` from the cache only — most
    /// fresh search results aren't cached, so the filter rejected them
    /// via the "missing = MISS" rule).
    ///
    /// Callers cap the input set (currently 20 — one REST page) to bound
    /// fan-out. The live impl fetches each id sequentially via the
    /// existing `RecipePageFetcher` + `JSONLDRecipeParser` plumbing so
    /// there's no new REST endpoint surface. Persists each hydrated
    /// `Recipe` via `mergeDetail(_:)` so subsequent filter flips hit the
    /// cache.
    func fetchTotalSeconds(forRecipeIDs ids: [Int]) async -> [Int: Int]
    /// US-29 / AC-29.1 amendment / CL-106 (T-637): companion to the
    /// "Latest Recipes" Try-pill special case. Fetches the N most-recent
    /// posts via the existing date-desc-by-default `WPRestClient.posts`
    /// endpoint. Returns up to `limit` items; the viewmodel over-fetches
    /// by ~1.5x at the call site so a few latest-articles-being-articles
    /// still leaves ~N recipes.
    func fetchLatestRecipes(limit: Int) async throws -> [RecipeListItem]
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
    /// US-12 / AC-12.3 amendment / CL-106 (T-637): JSON-LD detail fetcher
    /// reused for cook-time hydration on cache miss. Defaults to a stock
    /// `RecipePageFetcher()` (the same one the recipe-detail path uses) —
    /// the composition root keeps the original `init(client:store:monitor:)`
    /// shape, so the default keeps the existing call site at
    /// `App/AppDependencies.swift` byte-identical (no wiring change).
    let fetcher: RecipePageFetcher

    public init(
        client: WPRestClient,
        store: RecipeStore,
        monitor: NetworkMonitor,
        fetcher: RecipePageFetcher = RecipePageFetcher()
    ) {
        self.client = client
        self.store = store
        self.monitor = monitor
        self.fetcher = fetcher
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

    /// US-12 / AC-12.3 amendment / CL-106 (T-637): hydrate `totalSeconds`
    /// for the given recipe ids by fetching each post's rendered HTML and
    /// parsing the JSON-LD `totalTime`. Skips ids that already have a
    /// cached `totalSeconds` so we don't re-fetch known values. Each
    /// successfully parsed `Recipe` is written back to the cache via
    /// `store.mergeDetail(_:)` so subsequent filter flips hit the cache
    /// path (no network round-trip). Per-id failures are logged and
    /// silently dropped — the filter's "missing = MISS" rule still
    /// excludes them, which is the safer default than admitting a
    /// recipe whose total time we couldn't determine.
    public func fetchTotalSeconds(forRecipeIDs ids: [Int]) async -> [Int: Int] {
        guard !ids.isEmpty else { return [:] }
        var result: [Int: Int] = [:]
        // Drop ids that already have a cached total — no need to re-fetch.
        let cached = (try? await store.totalSeconds(forRecipeIDs: ids)) ?? [:]
        for (id, seconds) in cached { result[id] = seconds }
        let pending = ids.filter { cached[$0] == nil }
        for id in pending {
            do {
                let listItem = try await client.post(id: id)
                guard let canonicalURL = listItem.canonicalURL else { continue }
                let html = try await fetcher.html(for: canonicalURL)
                let recipe = try JSONLDRecipeParser.parse(
                    html: html,
                    merging: listItem,
                    canonicalURL: canonicalURL
                )
                // Cache write-back so subsequent flips hit the cache.
                try? await store.mergeDetail(recipe)
                if let total = recipe.totalTime {
                    result[id] = Int(total.components.seconds)
                }
            } catch {
                DODLog.network.error(
                    "search cook-time hydrate failed for id \(id): \(String(describing: error))"
                )
            }
        }
        return result
    }

    /// US-29 / AC-29.1 amendment / CL-106 (T-637): the "Latest Recipes"
    /// Try-pill special case fetches the N most-recent posts via the
    /// existing date-desc-by-default `posts` endpoint instead of running
    /// a literal text search for "Latest Recipes" (which returned garbage
    /// because the phrase appears in many unrelated articles' boilerplate).
    public func fetchLatestRecipes(limit: Int) async throws -> [RecipeListItem] {
        try await client.posts(page: 1, perPage: limit)
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

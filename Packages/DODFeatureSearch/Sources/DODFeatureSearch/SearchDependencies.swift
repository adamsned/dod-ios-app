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
    /// DUT-11: recipes that USE the given ingredient term, as ready-to-render
    /// `RecipeListItem`s sourced entirely from the local cache. De-duped (one
    /// row per recipe) and ordered by the ingredient-index fetch order. This
    /// is the single hop that backs the "Recipes using <term>" results tier —
    /// it folds the `searchIngredients(matching:)` + `cachedListItems(forIDs:)`
    /// round trip into one store call so the view model surfaces the section
    /// without two awaits. Purely local; works offline.
    func recipesUsingIngredient(matching query: String) async throws -> [RecipeListItem]
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
    /// US-12 / US-29 amendment / CL-121 (T-643): the category-name match
    /// path in `SearchViewModel.performSearch()`. Thin wrapper around the
    /// existing `WPRestClient.posts(categoryID:page:perPage:)` (live
    /// since T-081 / T-091 — no new REST surface; CL-121 explicitly
    /// requires reuse, not a new endpoint). Fetches up to `limit` posts
    /// in the named category in WP's natural date-desc order. Per typed
    /// query the viewmodel calls this at most ``CategoryNameMatcher.maxMatches``
    /// times (top-2 cap) — so the worst-case wire ceiling is two
    /// `?categories=<id>&per_page=100` pages.
    func fetchPosts(categoryID: Int, limit: Int) async throws -> [RecipeListItem]
    /// Set of recipe IDs the user has opened (any cached row). Drives the
    /// "Recently viewed" filter chip.
    func recentlyViewedRecipeIDs() async throws -> Set<Int>
    /// US-12 amendment / US-29 amendment / CL-127 (T-649): every cached
    /// recipe's title, used as the source pool for the "did you mean?"
    /// suggestion engine when the result set settles with fewer than
    /// 3 items. Wraps the existing `RecipeStore` cache; no new schema,
    /// no new REST surface. Returns `[]` on a fresh install (cold
    /// cache); the viewmodel short-circuits to a `nil` suggestion in
    /// that case.
    func cachedRecipeTitles() async throws -> [String]

    // MARK: - Filter chip data + empty-state suggestions
    /// All WP categories, alphabetized. Empty array on REST failure — the
    /// chip simply hides "All categories" submenu options rather than
    /// surfacing an error to the user during search.
    func allCategories() async throws -> [DODDomain.Category]

    // MARK: - Telemetry + connectivity
    func sendSearchTelemetry(queryHash: String) async
    func isOnline() async -> Bool
    /// T-765 / CL-162 (DUT-71) — saved recipe id set for the card long-press
    /// Save/Unsave label. Default `[]` keeps existing fake conformers compiling.
    func savedRecipeIDs() async throws -> Set<Int>
    /// DUT-534 Part 2 — append a recipe's ingredients to the Shopping List from a
    /// Search card's long-press "Add to Shopping List". The App composition root
    /// wires the shared `LiveShoppingListAppender`, which hydrates the
    /// (ingredient-empty, card-sourced) recipe before appending. Default
    /// `.couldntLoad` keeps existing fake conformers compiling and degrades
    /// gracefully when unwired.
    func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult
}

extension SearchDependencies {
    public func savedRecipeIDs() async throws -> Set<Int> { [] }
    public func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult { .couldntLoad }
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
    /// DUT-534 Part 2 — the App-wired Shopping List append seam. Routes a card's
    /// minimal (ingredient-empty) recipe to the shared `LiveShoppingListAppender`,
    /// which hydrates + appends. Optional so call sites that don't build shopping
    /// lists can omit it; `nil` reports `.couldntLoad`.
    public typealias ShoppingListAppendHook =
        @Sendable (Recipe) async -> AddToShoppingListResult
    private let shoppingListAppend: ShoppingListAppendHook?

    public init(
        client: WPRestClient,
        store: RecipeStore,
        monitor: NetworkMonitor,
        fetcher: RecipePageFetcher = RecipePageFetcher(),
        shoppingListAppend: ShoppingListAppendHook? = nil
    ) {
        self.client = client
        self.store = store
        self.monitor = monitor
        self.fetcher = fetcher
        self.shoppingListAppend = shoppingListAppend
    }

    /// DUT-534 Part 2 — route to the App-wired appender, or `.couldntLoad` when
    /// none is wired (previews / terse tests) so the UI never claims a row
    /// landed when nothing was persisted.
    public func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult {
        guard let shoppingListAppend else { return .couldntLoad }
        return await shoppingListAppend(recipe)
    }

    public func search(query: String) async throws -> [RecipeListItem] {
        try await client.search(query: query)
    }

    public func searchIngredients(matching query: String) async throws -> [Int] {
        try await store.searchIngredients(matching: query)
    }

    /// DUT-11: route to the value-type store query that maps matching
    /// ingredient-index rows to deduped `RecipeListItem`s. Read-only, local,
    /// no new REST surface — the constraint the ticket pins.
    public func recipesUsingIngredient(matching query: String) async throws -> [RecipeListItem] {
        try await store.recipesUsingIngredient(matching: query)
    }

    public func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        try await store.listItems(forIDs: ids)
    }

    public func cache(listItems: [RecipeListItem]) async throws {
        try await store.cache(listItems: listItems)
    }

    public func savedRecipeIDs() async throws -> Set<Int> {
        try await store.savedRecipeIDs()
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

    /// US-12 / US-29 amendment / CL-121 (T-643): the category-name match
    /// path in `SearchViewModel.performSearch()`. Routes to the existing
    /// `WPRestClient.posts(categoryID:page:perPage:)` — same surface the
    /// Feed / Category Recipes screens have been using since T-081 / T-091.
    /// No new REST endpoint; the category-match path is a pipeline-level
    /// addition over an existing client method per CL-121's "reuse don't
    /// add" rule.
    public func fetchPosts(categoryID: Int, limit: Int) async throws -> [RecipeListItem] {
        try await client.posts(categoryID: categoryID, page: 1, perPage: limit)
    }

    public func recentlyViewedRecipeIDs() async throws -> Set<Int> {
        try await store.recentlyViewedRecipeIDs()
    }

    /// US-12 amendment / US-29 amendment / CL-127 (T-649): wraps
    /// `RecipeStore.cachedRecipeTitles()`. The store reads the same
    /// `CachedRecipe` rows the rest of Search already touches; this
    /// path is read-only and additive.
    public func cachedRecipeTitles() async throws -> [String] {
        try await store.cachedRecipeTitles()
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

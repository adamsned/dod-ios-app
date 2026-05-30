import DODDomain
import DODSupport
import Foundation
import Observation

/// Debounced search view model. v2 adds a local ingredient-index pass, filter
/// chips, and a recent-searches history (US-12).
///
/// Spec trace: AC-3.1 (300ms debounce), AC-3.4 (empty state),
/// AC-3.6 (hashed query telemetry), AC-3.7 (offline),
/// AC-12.1..AC-12.6 (ingredient index + filters + recents + suggestions).
@Observable
@MainActor
public final class SearchViewModel {

    public enum State: Equatable {
        case idle
        case searching
        case results
        case noResults
        case offline
    }

    public var query: String = "" {
        didSet {
            // Any keystroke (or `selectRecent` call) routes through
            // `query = ...` directly; only `selectCuratedSuggestion(_:)`
            // sets the flag AFTER the assignment, so the default reset
            // here covers the typed + recent-tap paths.
            queryFromCuratedTap = false
            // US-29 / AC-29.1 amendment / CL-106 (T-637): a typed query
            // also reverts the surface back to the default text-search
            // path; the Latest-Recipes branch only stays "active" while
            // the items array still reflects the latest-recipes fetch.
            lastSurface = .textQuery
            scheduleSearch()
        }
    }

    /// `true` while the current `query` originated from a curated "Try"
    /// suggestion tap (US-29 / AC-29.1) rather than the user typing. Used
    /// so `performSearch()` does NOT persist the term to the recent-searches
    /// store — the user didn't intentionally search for it, they tapped a
    /// curated pill, and persisting it pollutes Recent with terms the user
    /// never typed (REG-19 / CL-66 / T-670).
    private var queryFromCuratedTap: Bool = false

    /// US-29 / AC-29.1 amendment / CL-106 (T-637): tracks how the current
    /// `items` array was sourced so filter mutations re-apply against the
    /// correct base set instead of re-running `reapplyFilters()` against
    /// an empty `lastQuery`. The Latest-Recipes branch fetches directly
    /// via `dependencies.fetchLatestRecipes(...)` without going through
    /// the normal text-search path; the surface flag lets the cook-time
    /// re-rank apply correctly when the user toggles a chip while the
    /// latest-recipes set is visible.
    enum Surface: Equatable {
        case textQuery
        case latestRecipes
    }
    // CL-106 (T-637): internal so the +T637 extension can write it.
    var lastSurface: Surface = .textQuery

    /// Filter chips state. Mutating a filter forces an immediate re-rank of
    /// the cached merged results — no network round trip — so the UI feels
    /// instant. If the merged set is empty (idle / cleared), changing a
    /// filter is a no-op other than the chip's visual state.
    public var filters = SearchFilters() {
        didSet {
            guard oldValue != filters else { return }
            reapplyFilters()
        }
    }

    // CL-106 (T-637): promoted to `public internal(set)` so the
    // `SearchViewModel+T637.swift` extension can set `.searching` /
    // `.offline` / `.results` / `.noResults` on the Latest-Recipes branch.
    public internal(set) var state: State = .idle
    /// The post-filter, post-merge result set bound to the view.
    ///
    /// CL-106 (T-637): promoted from `public private(set)` to
    /// `public internal(set)` so the same-module
    /// `SearchViewModel+T637.swift` extension can write the
    /// Latest-Recipes branch's result set directly. Read surface unchanged.
    public internal(set) var items: [RecipeListItem] = []
    /// Last user-typed query that produced `items`. Used so filter changes
    /// can re-merge without re-running the network call. CL-106 (T-637)
    /// promotes the setter to `internal` for the same Latest-Recipes
    /// extension-write reason as `items` above.
    public internal(set) var lastQuery: String = ""
    /// Categories list for the category chip menu. Loaded lazily.
    public private(set) var availableCategories: [DODDomain.Category] = []
    /// Top-5 suggestions (by recipe count) shown in the idle empty state.
    public var topCategorySuggestions: [DODDomain.Category] {
        Array(availableCategories.sorted { $0.count > $1.count }.prefix(5))
    }
    /// Newest-first recent queries.
    public private(set) var recentSearches: [String] = []

    // CL-106 (T-637): the next five caches and `dependencies` are
    // `internal` (no access modifier) rather than `private` so the
    // `SearchViewModel+T637.swift` extension can read/write them when
    // applying the Latest-Recipes surface or firing cook-time hydration.
    // Same-module extensions cannot reach `private` storage, and we want
    // the new code in its own file for the file-length budget. The
    // public surface is unchanged.
    var lastMergedRESTOrdering: [RecipeListItem] = []
    var lastMergedLocalOrdering: [RecipeListItem] = []
    var lastCategoryIDsByRecipe: [Int: [Int]] = [:]
    var lastTotalSecondsByRecipe: [Int: Int] = [:]
    var lastRecentlyViewedIDs: Set<Int> = []

    let dependencies: SearchDependencies
    private let recents: RecentSearches
    /// Public for tests to control timing without sleeping for real.
    public var debounceMilliseconds: Int = 300
    private var debounceTask: Task<Void, Never>?

    public init(
        dependencies: SearchDependencies,
        recentSearches: RecentSearches = RecentSearches()
    ) {
        self.dependencies = dependencies
        self.recents = recentSearches
        self.recentSearches = recentSearches.recent()
    }

    public func clear() {
        query = ""
        items = []
        lastQuery = ""
        state = .idle
        lastMergedRESTOrdering = []
        lastMergedLocalOrdering = []
        lastSurface = .textQuery
    }

    /// Surface a stored query (e.g. user tapped a recent chip). Sets the
    /// field and triggers the search synchronously through the same path
    /// as typing.
    public func selectRecent(_ query: String) {
        self.query = query
    }

    /// Surface a curated "Try" suggestion (US-29 / AC-29.1) — e.g. the
    /// user tapped a top-category pill in the idle empty state. Same
    /// debounce + REST path as typing, but the resulting query is
    /// flagged as `queryFromCuratedTap` so `performSearch()` does NOT
    /// persist it to the recent-searches store. The user did not type
    /// the term; persisting curated names ("Bourbon", "Sweet Potato",
    /// "Brisket", etc.) into Recent makes Clear All look broken because
    /// the same curated suggestions reappear on the next idle render.
    ///
    /// Spec trace: REG-19 / CL-66 / T-670.
    public func selectCuratedSuggestion(_ query: String) {
        self.query = query
        queryFromCuratedTap = true
    }

    // US-29 / AC-29.1 amendment / CL-106 (T-637): the "Latest Recipes"
    // Try-pill special case (`surfaceLatestRecipes(limit:)`) lives in
    // `SearchViewModel+T637.swift` so this file stays under SwiftLint's
    // `file_length` cap. The branch is wired from `SearchView` when the
    // tapped category matches "Latest Recipes" by name or id 1590.

    /// Wipe the persisted recent-searches store and update the
    /// view-bound `recentSearches` array so the "Recent" section
    /// disappears on the next observation tick. Backed by the existing
    /// `RecentSearches.clear()` method.
    ///
    /// Also cancels any in-flight debounced search so a `performSearch()`
    /// that started before Clear All cannot re-record the just-cleared
    /// query after the wipe completes (REG-19 / CL-66 / T-670 — defensive
    /// belt on top of the curated-tap skip; covers the typed-then-immediately-
    /// cleared race too).
    ///
    /// Spec trace: US-29 / AC-29.2 (Clear All affordance), CL-49.2
    /// (single-source-of-truth routing through the view-model), CL-66
    /// (in-flight cancellation closes the race).
    public func clearRecentSearches() {
        debounceTask?.cancel()
        recents.clear()
        recentSearches = recents.recent()
    }

    /// Remove a single term from the persisted recent-searches store
    /// (case-insensitive match per `RecentSearches.remove(_:)`) and
    /// refresh the view-bound `recentSearches` array so the FlowLayout
    /// re-renders without the dropped pill on the next observation tick.
    ///
    /// Spec trace: US-33 / AC-33.3 (per-term context-menu Clear),
    /// CL-57 (recents-store mutations route through the view-model).
    public func removeRecentSearch(_ query: String) {
        recents.remove(query)
        recentSearches = recents.recent()
    }

    /// Load categories so the chip menu and the empty-state suggestions can
    /// render. Idempotent — fetches once per session unless explicitly
    /// refreshed.
    public func loadCategoriesIfNeeded() async {
        guard availableCategories.isEmpty else { return }
        let fetched = (try? await dependencies.allCategories()) ?? []
        availableCategories = fetched
    }

    /// For tests: bypass the debounce.
    public func runImmediateSearch() async {
        debounceTask?.cancel()
        await performSearch()
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            items = []
            state = .idle
            return
        }
        debounceTask = Task { [weak self] in
            guard let self else { return }
            let delay = await self.debounceMilliseconds
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            if Task.isCancelled { return }
            await self.performSearch()
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }

        // The local ingredient index works offline; the REST pass does not.
        // We try both and gracefully degrade: if REST is down but the user
        // has previously viewed a few recipes that match by ingredient,
        // they still see results instead of a hard "offline" screen.
        let online = await dependencies.isOnline()

        state = .searching
        var restResults: [RecipeListItem] = []
        if online {
            do {
                restResults = try await dependencies.search(query: trimmed)
                try? await dependencies.cache(listItems: restResults)
            } catch {
                DODLog.network.error("search REST failed: \(String(describing: error))")
            }
        }

        let localIDs = (try? await dependencies.searchIngredients(matching: trimmed)) ?? []
        let localItems = (try? await dependencies.cachedListItems(forIDs: localIDs)) ?? []

        let merged = SearchResultMerger.merge(
            query: trimmed,
            restResults: restResults,
            localIngredientResults: localItems
        )

        // No results AND we're offline AND there was nothing local — that's
        // the true offline state. If we got even one local hit, we treat
        // it as a results screen.
        if merged.isEmpty && !online {
            state = .offline
            items = []
            return
        }

        // Cache the inputs so filter mutations can re-rank without I/O.
        lastQuery = trimmed
        lastMergedRESTOrdering = restResults
        lastMergedLocalOrdering = localItems
        lastSurface = .textQuery

        let allIDs = merged.map(\.id)
        lastCategoryIDsByRecipe =
            (try? await dependencies.categoryIDs(forRecipeIDs: allIDs)) ?? [:]
        lastTotalSecondsByRecipe =
            (try? await dependencies.totalSeconds(forRecipeIDs: allIDs)) ?? [:]
        lastRecentlyViewedIDs =
            (try? await dependencies.recentlyViewedRecipeIDs()) ?? []

        let filtered = filters.apply(
            to: merged,
            categoryIDsByRecipe: lastCategoryIDsByRecipe,
            totalSecondsByRecipe: lastTotalSecondsByRecipe,
            recentlyViewedIDs: lastRecentlyViewedIDs
        )
        items = filtered
        state = filtered.isEmpty ? .noResults : .results

        await recordRecentAndTelemetry(trimmed: trimmed)
        kickOffCookTimeHydrationIfNeeded(against: merged)
    }

    /// Record the recent on a successful query — even if zero results,
    /// because "tried it, didn't work" is still useful history. Skip
    /// when the query originated from a curated "Try" suggestion tap
    /// (REG-19 / CL-66 / T-670): the user didn't type it, so persisting
    /// it into Recent would surface curated terms the user never asked
    /// for, and tapping Clear All would not actually clear them on the
    /// next idle render. Also sends the AC-3.6 SHA-256-hashed query to
    /// analytics (the raw text never leaves the device).
    ///
    /// Extracted from `performSearch` so the parent stays under
    /// SwiftLint's `function_body_length` cap (CL-106 / T-637's hydration
    /// kick-off pushed it over).
    private func recordRecentAndTelemetry(trimmed: String) async {
        if !queryFromCuratedTap {
            recents.record(trimmed)
            recentSearches = recents.recent()
        }
        let hash = StringHasher.sha256Hex(trimmed)
        await dependencies.sendSearchTelemetry(queryHash: hash)
    }

    /// US-12 / AC-12.3 amendment / CL-106 (T-637): when the cook-time
    /// filter is active and the cached `lastTotalSecondsByRecipe` map is
    /// missing entries for items in the current result set, kick off a
    /// network hydration task (capped at 20 items per `hydrationCap`)
    /// and call `reapplyFilters()` when the data lands. No-op when the
    /// filter is off or every visible item already has a known total
    /// time (the cache covers it).
    ///
    /// The hydration task runs detached on the same actor (this is the
    /// `@MainActor` view model — `Task { ... }` inherits the actor) so
    /// the mutation of `lastTotalSecondsByRecipe` and the subsequent
    /// `reapplyFilters()` call are race-free.
    func kickOffCookTimeHydrationIfNeeded(against merged: [RecipeListItem]) {
        guard filters.cookTime != nil else { return }
        let unknown = merged.map(\.id).filter { lastTotalSecondsByRecipe[$0] == nil }
        guard !unknown.isEmpty else { return }
        let toFetch = Array(unknown.prefix(Self.hydrationCap))
        Task { [weak self] in
            guard let self else { return }
            let fetched = await self.dependencies.fetchTotalSeconds(forRecipeIDs: toFetch)
            guard !fetched.isEmpty else { return }
            for (id, seconds) in fetched {
                self.lastTotalSecondsByRecipe[id] = seconds
            }
            self.reapplyFilters()
        }
    }

    /// One REST page worth of items — bounds the cook-time hydration
    /// fan-out so a single filter toggle can't hammer the API. Matches
    /// `WPRestClient.defaultPageSize` (20) by convention.
    private static let hydrationCap: Int = 20

    /// Re-rank the cached merged set when filters change. Pure function over
    /// stored state — no I/O (apart from the optional cook-time hydration
    /// path below, which fires only when the cook-time filter just flipped
    /// on against items whose total time isn't in the cache).
    ///
    /// CL-106 (T-637): also handles the Latest-Recipes surface — when
    /// `lastSurface == .latestRecipes`, the base set is
    /// `lastMergedRESTOrdering` (no `SearchResultMerger` call because
    /// there's no text query to re-rank around), so the filter re-runs
    /// against the latest-recipes fetch result directly.
    private func reapplyFilters() {
        let base: [RecipeListItem]
        switch lastSurface {
        case .textQuery:
            guard !lastQuery.isEmpty else { return }
            base = SearchResultMerger.merge(
                query: lastQuery,
                restResults: lastMergedRESTOrdering,
                localIngredientResults: lastMergedLocalOrdering
            )
        case .latestRecipes:
            guard !lastMergedRESTOrdering.isEmpty else { return }
            base = lastMergedRESTOrdering
        }
        let filtered = filters.apply(
            to: base,
            categoryIDsByRecipe: lastCategoryIDsByRecipe,
            totalSecondsByRecipe: lastTotalSecondsByRecipe,
            recentlyViewedIDs: lastRecentlyViewedIDs
        )
        items = filtered
        state = filtered.isEmpty ? .noResults : .results

        // If the cook-time filter is on and the base set still has items
        // with unknown total times, fire hydration. The kick-off helper
        // guards against the cook-time-off case so this is safe to call
        // unconditionally.
        kickOffCookTimeHydrationIfNeeded(against: base)
    }
}

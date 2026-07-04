import DODDomain
import DODSupport
import Foundation
import Observation

/// Debounced search view model. v2 adds a local ingredient-index pass, filter
/// chips, and a recent-searches history (US-12).
///
/// Spec trace: AC-3.1 (150ms debounce, DUT-10; was 300ms), AC-3.4 (empty state),
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
            // DUT-435: a mutated query re-arms the finalized-search commit.
            lastCommittedQuery = nil
            // US-29 / AC-29.1 amendment / CL-106 (T-637): a typed query
            // also reverts the surface back to the default text-search
            // path; the Latest-Recipes branch only stays "active" while
            // the items array still reflects the latest-recipes fetch.
            lastSurface = .textQuery
            scheduleSearch()
        }
    }

    /// DUT-435 — the trimmed query most recently committed by
    /// ``commitRecentSearch()``, nil once the query mutates. Return fires BOTH
    /// `.onSubmit` and the focus-loss commit; this guard stops the duplicate
    /// `recipe_searched` event. Internal for the `+Recents` extension.
    var lastCommittedQuery: String?

    /// `true` while the current `query` originated from a curated "Try"
    /// suggestion tap (US-29 / AC-29.1) rather than the user typing. Used
    /// so `performSearch()` does NOT persist the term to the recent-searches
    /// store — the user didn't intentionally search for it, they tapped a
    /// curated pill, and persisting it pollutes Recent with terms the user
    /// never typed (REG-19 / CL-66 / T-670).
    /// T-779 / DUT-85: `private(set)` (was `private`) so the `+Recents`
    /// extension's `commitRecentSearch()` can read the curated-tap flag.
    private(set) var queryFromCuratedTap: Bool = false

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
    /// DUT-11: the "Recipes using <term>" tier — recipes whose *ingredient
    /// list* contains the query but that did NOT already match by title or
    /// category (never duplicated in `items`). Sourced from the local
    /// `CachedIngredient` index (so it populates offline) and rendered as a
    /// labeled section beneath the title results in ``SearchView``, which is
    /// what tells the user why a title-less recipe matched. Filter chips do
    /// NOT narrow this discovery tier in v1.
    public internal(set) var ingredientItems: [RecipeListItem] = []
    /// T-765 / CL-162 — saved recipe ids for the card menu (see `SearchViewModel+SavedState`).
    public internal(set) var savedRecipeIDs: Set<Int> = []
    /// DUT-534 Part 2 — Shopping List snackbar copy + optional trailing action
    /// title ("View"), driven by `SearchViewModel+ShoppingList`, rendered by
    /// `SearchView`. `nil` message hides the snackbar.
    public internal(set) var shoppingListSnackbarMessage: String?
    public internal(set) var shoppingListSnackbarActionTitle: String?
    /// Last user-typed query that produced `items` (so filter changes re-merge
    /// without a network call). `internal(set)` for the T-637 extension write.
    public internal(set) var lastQuery: String = ""
    /// Categories list for the category chip menu. Loaded lazily.
    public private(set) var availableCategories: [DODDomain.Category] = []
    /// Top-5 suggestions (by recipe count). **Preserved for backward
    /// compatibility only** — `IdleSuggestionsView` consumes
    /// `displayedTrySlate` (T-639 / CL-117) instead. Kept on the public
    /// surface in case any future consumer (analytics, snapshot, etc.)
    /// wants the pre-rotation top-5 view.
    public var topCategorySuggestions: [DODDomain.Category] {
        Array(availableCategories.sorted { $0.count > $1.count }.prefix(5))
    }

    /// US-29 amendment / CL-117 / T-639: the rotating Try slate's storage
    /// + helpers (`topTrySlatePool`, `displayedTrySlate`, `pickTrySlate`)
    /// live in `SearchViewModel+T639.swift` to keep this file under
    /// SwiftLint's `file_length` cap. The backing cache is here because
    /// stored properties can't live in extensions.
    var cachedTrySlate: [DODDomain.Category]?

    /// Newest-first recent queries. T-779 / DUT-85: `internal(set)` (was
    /// `private(set)`) so the `+Recents` extension can refresh it on commit.
    public internal(set) var recentSearches: [String] = []

    /// CL-127 (T-649): "did you mean?" suggestion populated by the
    /// `+T643` finalize hop when results settle < 3 items.
    public internal(set) var didYouMean: String?

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
    /// DUT-314: `false` after a default search skipped the filter-support
    /// fetches, so the first chip toggle lazily hydrates (see `+DUT314`).
    var filterSupportHydrated = false

    let dependencies: SearchDependencies
    // T-779 / DUT-85: internal (was `private`) so `+Recents` can record into it.
    let recents: RecentSearches
    /// Autocomplete debounce (DUT-10: tightened 300 -> 150ms). Public so tests control timing.
    public var debounceMilliseconds: Int = 150
    // DUT-534 Part 2 — internal (was `private`) so `+Recents.clearRecentSearches`
    // (moved there for file-length relief) can cancel the in-flight debounce.
    var debounceTask: Task<Void, Never>?
    /// H1 (SDET 2026-06-28): monotonic search-generation token. Bumped at the
    /// start of every `performSearch()`; async completions (the finalize hop +
    /// the lazy filter / cook-time hydration tasks) capture it and bail if a
    /// newer search has superseded them — so a slow earlier query can't
    /// overwrite a faster later one's results. Fully internal (DUT-436) so
    /// `+T637`'s `surfaceLatestRecipes` can claim a generation too.
    var searchGeneration = 0

    /// DUT-541: in-flight guard for card "Add to Shopping List". A rapid double
    /// long-press fires two independent `Task { await addToShoppingList(item) }`
    /// with no gate, and `ShoppingListStore.append` is additive (CL-77), so the
    /// same recipe's ingredients would be appended twice. `addToShoppingList`
    /// records an item's id here while its append is in flight and bails if the
    /// SAME id is already in flight — blocking only the concurrent duplicate.
    /// Different recipes are unaffected, and a deliberate re-add AFTER the first
    /// completes still stacks (CL-77 preserved). Internal so `+ShoppingList`
    /// reaches it; main-actor-isolated, so the `Set` access needs no locking.
    var addingIDs = Set<Int>()

    public init(
        dependencies: SearchDependencies,
        recentSearches: RecentSearches = RecentSearches()
    ) {
        self.dependencies = dependencies
        self.recents = recentSearches
        self.recentSearches = recentSearches.recent()
    }

    public func clear() {
        // DUT-221: cancel the in-flight debounce AND bump the generation so a
        // slow query already past the debounce (awaiting the REST fan-out) bails
        // in `finishTextSearch` rather than repainting over the now-idle screen.
        debounceTask?.cancel()
        searchGeneration &+= 1
        query = ""
        items = []
        ingredientItems = []  // DUT-11: wipe the ingredient tier too.
        lastQuery = ""
        state = .idle
        lastMergedRESTOrdering = []
        lastMergedLocalOrdering = []
        lastSurface = .textQuery
        didYouMean = nil  // CL-127 (T-649): wipe the rescue banner too.
        filterSupportHydrated = false  // DUT-505: re-arm lazy filter-support hydration.
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
            // DUT-221: bump the generation so an earlier ≥2-char search still in
            // flight bails rather than repainting over the reset-to-idle screen.
            searchGeneration &+= 1
            items = []
            ingredientItems = []  // DUT-11: don't strand a stale tier.
            state = .idle
            filterSupportHydrated = false  // DUT-505: re-arm lazy filter-support hydration.
            return
        }
        debounceTask = Task { [weak self] in
            guard let self else { return }
            let delay = self.debounceMilliseconds
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            if Task.isCancelled { return }
            await self.performSearch()
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        // H1: claim a new generation; stale async completions check it + bail.
        searchGeneration &+= 1
        let generation = searchGeneration

        // The local ingredient index works offline; the REST pass does not.
        // We try both and gracefully degrade (see the DUT-11 tier below).
        let online = await dependencies.isOnline()

        state = .searching
        let (restResults, categoryResults) = await fanOutSearchPaths(
            trimmed: trimmed,
            online: online
        )

        // DUT-11: the local "Recipes using <term>" tier — works offline.
        let localItems =
            (try? await dependencies.recipesUsingIngredient(matching: trimmed)) ?? []

        let titleMerged = SearchResultMerger.merge(
            query: trimmed,
            restResults: restResults,
            localIngredientResults: localItems
        )
        // T-643 / CL-121: union the title-tier-ordered Path A results
        // with the category-fetched Path B results, deduped by post id.
        // Path A's tier ordering (exact → substring → fuzzy) survives the
        // union; Path B-only contributions append in WP's natural date-
        // desc order. See `CategoryNameMatcher` doc-comment for the rule.
        let merged = mergeWithCategoryResults(
            titleMerged: titleMerged,
            categoryResults: categoryResults
        )

        // DUT-11: dedup ingredient tier + offline guard + cache stash
        // (`finishTextSearch` lives in `+T643` for the body-length cap).
        await finishTextSearch(
            merged: merged,
            localItems: localItems,
            trimmed: trimmed,
            online: online,
            generation: generation
        )
    }

    // CL-121 (T-643) + DUT-11: the `performSearch` helpers (fan-out / Path A
    // / Path B / merge / finish / finalize) live in `SearchViewModel+T643.swift`
    // so this file stays under SwiftLint's `file_length` cap.

    /// Send the AC-3.6 SHA-256-hashed query to analytics on each completed
    /// search. T-779 / DUT-85 moved recent-recording out of this path into
    /// ``commitRecentSearch()`` (Return / keyboard dismissal only), so this no
    /// longer persists to the recents store. `+T643`'s finalize hop calls it.
    func sendSearchTelemetry(trimmed: String) async {
        let hash = StringHasher.sha256Hex(trimmed)
        await dependencies.sendSearchTelemetry(queryHash: hash)
    }

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
    ///
    /// CL-121 (T-643): the `.textQuery` branch now uses the cached
    /// post-union shape directly (no `SearchResultMerger` re-run). The
    /// `lastMergedRESTOrdering` field was promoted by `performSearch()`
    /// to hold the full Path A + Path B union; re-running the merger
    /// would re-apply the title-precision filter and drop the Path B-only
    /// category contributions — exactly the regression T-643 fixes.
    ///
    /// DUT-314: `internal` (was `private`) so `+DUT314`'s lazy hydration can
    /// re-rank once the skipped filter-support caches land.
    func reapplyFilters() {
        let base: [RecipeListItem]
        switch lastSurface {
        case .textQuery:
            guard !lastQuery.isEmpty, !lastMergedRESTOrdering.isEmpty else { return }
            base = lastMergedRESTOrdering
        case .latestRecipes:
            guard !lastMergedRESTOrdering.isEmpty else { return }
            base = lastMergedRESTOrdering
        }
        // DUT-314: when a default search skipped the filter-support fetches,
        // the first chip toggle lazily hydrates them and re-ranks once they
        // land (no-op on repeat toggles — see `+DUT314`).
        kickOffFilterSupportHydrationIfNeeded(against: base)
        let filtered = filters.apply(
            to: base,
            categoryIDsByRecipe: lastCategoryIDsByRecipe,
            totalSecondsByRecipe: lastTotalSecondsByRecipe,
            recentlyViewedIDs: lastRecentlyViewedIDs
        )
        items = filtered
        // DUT-11: leave `ingredientItems` untouched — chips re-rank only the
        // title tier; the ingredient tier stays visible across toggles. Stay
        // on `.results` when EITHER tier has content.
        state = (filtered.isEmpty && ingredientItems.isEmpty) ? .noResults : .results

        // If the cook-time filter is on and the base set still has items
        // with unknown total times, fire hydration. The kick-off helper
        // guards against the cook-time-off case so this is safe to call
        // unconditionally.
        kickOffCookTimeHydrationIfNeeded(against: base)
    }
}

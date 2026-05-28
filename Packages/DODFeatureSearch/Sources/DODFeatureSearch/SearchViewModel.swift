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

    public private(set) var state: State = .idle
    /// The post-filter, post-merge result set bound to the view.
    public private(set) var items: [RecipeListItem] = []
    /// Last user-typed query that produced `items`. Used so filter changes
    /// can re-merge without re-running the network call.
    public private(set) var lastQuery: String = ""
    /// Categories list for the category chip menu. Loaded lazily.
    public private(set) var availableCategories: [DODDomain.Category] = []
    /// Top-5 suggestions (by recipe count) shown in the idle empty state.
    public var topCategorySuggestions: [DODDomain.Category] {
        Array(availableCategories.sorted { $0.count > $1.count }.prefix(5))
    }
    /// Newest-first recent queries.
    public private(set) var recentSearches: [String] = []

    private var lastMergedRESTOrdering: [RecipeListItem] = []
    private var lastMergedLocalOrdering: [RecipeListItem] = []
    private var lastCategoryIDsByRecipe: [Int: [Int]] = [:]
    private var lastTotalSecondsByRecipe: [Int: Int] = [:]
    private var lastRecentlyViewedIDs: Set<Int> = []

    private let dependencies: SearchDependencies
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

        // Record the recent on a successful query — even if zero results,
        // because "tried it, didn't work" is still useful history. Skip
        // when the query originated from a curated "Try" suggestion tap
        // (REG-19 / CL-66 / T-670): the user didn't type it, so persisting
        // it into Recent would surface curated terms the user never asked
        // for, and tapping Clear All would not actually clear them on the
        // next idle render.
        if !queryFromCuratedTap {
            recents.record(trimmed)
            recentSearches = recents.recent()
        }

        // AC-3.6: telemetry sends ONLY the hash, never the raw query.
        let hash = StringHasher.sha256Hex(trimmed)
        await dependencies.sendSearchTelemetry(queryHash: hash)
    }

    /// Re-rank the cached merged set when filters change. Pure function over
    /// stored state — no I/O.
    private func reapplyFilters() {
        guard !lastQuery.isEmpty else { return }
        let merged = SearchResultMerger.merge(
            query: lastQuery,
            restResults: lastMergedRESTOrdering,
            localIngredientResults: lastMergedLocalOrdering
        )
        let filtered = filters.apply(
            to: merged,
            categoryIDsByRecipe: lastCategoryIDsByRecipe,
            totalSecondsByRecipe: lastTotalSecondsByRecipe,
            recentlyViewedIDs: lastRecentlyViewedIDs
        )
        items = filtered
        state = filtered.isEmpty ? .noResults : .results
    }
}

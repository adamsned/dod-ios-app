import DODDomain
import DODSupport
import Foundation

/// CL-121 (T-643): the four `SearchViewModel.performSearch()` helpers that
/// fan out and union the parallel title + category match paths. Split out
/// of `SearchViewModel.swift` so that file stays under SwiftLint's
/// `file_length` (400-line) + `type_body_length` (250-line) caps after the
/// T-643 category-match path doubled the per-query REST fan-out.
///
/// Same split pattern the T-637 (`+T637`) / T-639 (`+T639`) / T-640
/// (`+T640`) extensions already follow on this view-model. Helpers live
/// in the extension; the storage they read (`availableCategories`,
/// `dependencies`) is `internal` on the main type for the same reason
/// (CL-106 cited this requirement when promoting the storage from
/// `private` to `internal`).
extension SearchViewModel {

    /// Fire Path A (REST `?search=<query>`) and Path B (REST `?categories=`
    /// per matched category, top-2 cap) in parallel via `async let`. Both
    /// short-circuit to `[]` when offline so the existing offline-state
    /// branch in `performSearch()` keeps working without a network round-
    /// trip. Path B's failure does NOT block Path A — each failure path
    /// logs and returns `[]`, so the caller always gets a usable tuple.
    func fanOutSearchPaths(
        trimmed: String,
        online: Bool
    ) async -> (restResults: [RecipeListItem], categoryResults: [RecipeListItem]) {
        guard online else { return ([], []) }
        async let restTask = fetchTitleSearchOrEmpty(trimmed: trimmed)
        async let categoryTask = fetchCategoryMatchesOrEmpty(trimmed: trimmed)
        return await (restTask, categoryTask)
    }

    /// Path A wrapper: REST `?search=<query>` → `[RecipeListItem]`, plus
    /// the existing background cache-write. Errors are logged and return
    /// `[]` so the caller's tuple is never the source of a thrown error.
    func fetchTitleSearchOrEmpty(trimmed: String) async -> [RecipeListItem] {
        do {
            let restResults = try await dependencies.search(query: trimmed)
            try? await dependencies.cache(listItems: restResults)
            return restResults
        } catch {
            DODLog.network.error("search REST failed: \(String(describing: error))")
            return []
        }
    }

    /// Path B wrapper: match the typed query against the loaded category
    /// list via `CategoryNameMatcher`, fetch posts for each matched
    /// category (top-2 cap baked into the matcher), and concat the
    /// results in match-order (highest count first). Failure is logged
    /// and silently returns `[]` so Path A still renders — graceful
    /// degradation per CL-121's "Path B failure does NOT block Path A"
    /// rule.
    func fetchCategoryMatchesOrEmpty(trimmed: String) async -> [RecipeListItem] {
        let matched = CategoryNameMatcher.match(
            query: trimmed,
            in: availableCategories
        )
        guard !matched.isEmpty else { return [] }
        var combined: [RecipeListItem] = []
        for category in matched {
            do {
                let posts = try await dependencies.fetchPosts(
                    categoryID: category.id,
                    limit: 100
                )
                // Cache the category-fetched items the same way the
                // search path does — keeps the local cache warm for
                // detail-screen opens.
                try? await dependencies.cache(listItems: posts)
                combined.append(contentsOf: posts)
            } catch {
                let categoryID = category.id
                let description = String(describing: error)
                DODLog.network.error(
                    "search category fetch failed for id \(categoryID): \(description)"
                )
            }
        }
        return combined
    }

    /// Union the Path A (title-tier ordered) and Path B (category-fetch,
    /// natural date-desc) result sets, deduped by post id. Title-tier
    /// ordering wins on overlap — a post that matches BOTH paths keeps
    /// the Path A tier rank rather than dropping back to date order.
    /// Pure value-type function; no I/O.
    func mergeWithCategoryResults(
        titleMerged: [RecipeListItem],
        categoryResults: [RecipeListItem]
    ) -> [RecipeListItem] {
        guard !categoryResults.isEmpty else { return titleMerged }
        var seen: Set<Int> = Set(titleMerged.map(\.id))
        var unioned = titleMerged
        for item in categoryResults where !seen.contains(item.id) {
            unioned.append(item)
            seen.insert(item.id)
        }
        return unioned
    }

    /// DUT-11: the tail of `performSearch()` after the title/category union
    /// is computed. Derives the ingredient tier (recipes that USE the term
    /// but were NOT already surfaced by title/category, so no row is shown
    /// twice), applies the both-tiers-empty offline guard, stashes the
    /// filter-re-rank caches, and hands off to `applyFiltersAndFinalize`.
    /// Extracted from `performSearch()` so that method stays under SwiftLint's
    /// `function_body_length` cap.
    func finishTextSearch(
        merged: [RecipeListItem],
        localItems: [RecipeListItem],
        trimmed: String,
        online: Bool
    ) async {
        let titleIDs = Set(merged.map(\.id))
        let ingredientOnly = localItems.filter { !titleIDs.contains($0.id) }

        // True offline state only when BOTH tiers are empty. A local
        // ingredient hit needs no network, so it keeps the user on a results
        // screen even with REST down — the offline-resilience win DUT-11
        // unlocks on top of CL-120's title-precision contract.
        if merged.isEmpty, ingredientOnly.isEmpty, !online {
            state = .offline
            items = []
            ingredientItems = []
            return
        }

        // Cache the inputs so filter mutations can re-rank without I/O.
        // T-643: `lastMergedRESTOrdering` carries the post-union REST shape
        // (title + category) so a filter mutation re-runs against the same
        // set the user sees, not just the title-path subset.
        lastQuery = trimmed
        lastMergedRESTOrdering = merged
        lastMergedLocalOrdering = localItems
        lastSurface = .textQuery
        ingredientItems = ingredientOnly

        await applyFiltersAndFinalize(merged: merged, trimmed: trimmed)
    }

    /// Final hop of `performSearch()`: hydrate the filter-support maps,
    /// apply the filter chips, set `items` + `state`, and fire the
    /// recents/telemetry + cook-time hydration tails. Extracted so
    /// `performSearch()` stays under the function-body cap after the
    /// T-643 fan-out tuple was inlined into it.
    func applyFiltersAndFinalize(
        merged: [RecipeListItem],
        trimmed: String
    ) async {
        let allIDs = merged.map(\.id)
        // DUT-314: `filters.apply` short-circuits to `items` unchanged when
        // `filters.isAllDefault`, so the three filter-support fetches below
        // (the last of which is a full `CachedRecipe` table scan) feed maps
        // that go unread on the common no-filter search. Gate them behind
        // `!isAllDefault` and pass empties through — behaviour-preserving,
        // it just skips three persistence round-trips per default search.
        if filters.isAllDefault {
            lastCategoryIDsByRecipe = [:]
            lastTotalSecondsByRecipe = [:]
            lastRecentlyViewedIDs = []
            // The caches are deliberately empty — a later chip toggle lazily
            // hydrates them (see `reapplyFilters` /
            // `kickOffFilterSupportHydrationIfNeeded`).
            filterSupportHydrated = false
        } else {
            lastCategoryIDsByRecipe =
                (try? await dependencies.categoryIDs(forRecipeIDs: allIDs)) ?? [:]
            lastTotalSecondsByRecipe =
                (try? await dependencies.totalSeconds(forRecipeIDs: allIDs)) ?? [:]
            lastRecentlyViewedIDs =
                (try? await dependencies.recentlyViewedRecipeIDs()) ?? []
            filterSupportHydrated = true
        }

        let filtered = filters.apply(
            to: merged,
            categoryIDsByRecipe: lastCategoryIDsByRecipe,
            totalSecondsByRecipe: lastTotalSecondsByRecipe,
            recentlyViewedIDs: lastRecentlyViewedIDs
        )
        items = filtered
        // DUT-11: a query can land zero title hits yet still surface recipes
        // that USE the term (the ingredient tier). Stay on `.results` whenever
        // EITHER tier has content so the labeled "Recipes using <term>"
        // section renders; only fall to `.noResults` when both are empty.
        state = (filtered.isEmpty && ingredientItems.isEmpty) ? .noResults : .results

        // CL-127 (T-649): compute the "did you mean?" suggestion when
        // the result set settles sparse (fewer than 3 items). The
        // suggestion engine is pure; the only I/O is the cached-titles
        // fetch from the existing `RecipeStore` cache, no network. We
        // gate on `!trimmed.isEmpty` (the trimmed query the caller
        // validated has at least 2 chars per `scheduleSearch`) so a
        // cleared query never produces a suggestion.
        //
        // DUT-11: count BOTH tiers toward "sparse" — a query that returns
        // plenty of recipes-that-use-the-term shouldn't get a "did you mean?"
        // rescue banner just because the title tier was thin.
        await computeDidYouMean(
            itemCount: filtered.count + ingredientItems.count,
            trimmed: trimmed
        )

        await sendSearchTelemetry(trimmed: trimmed)
        kickOffCookTimeHydrationIfNeeded(against: merged)
    }

    /// US-12 amendment / US-29 amendment / CL-127 (T-649): the
    /// suggestion compute hop. Runs only when the result set is sparse
    /// (< 3 items); clears `didYouMean` otherwise so a follow-up search
    /// that lands a populated result page wipes a stale banner. The
    /// cached-titles fetch is wrapped in `try?` so a cold cache fall-
    /// through degrades to `nil` (engine returns nil on an empty pool,
    /// same outcome).
    func computeDidYouMean(itemCount: Int, trimmed: String) async {
        guard itemCount < Self.didYouMeanThreshold, !trimmed.isEmpty else {
            didYouMean = nil
            return
        }
        let cachedTitles = (try? await dependencies.cachedRecipeTitles()) ?? []
        didYouMean = SearchSuggestionEngine.suggest(
            query: trimmed,
            cachedTitles: cachedTitles
        )
    }
}

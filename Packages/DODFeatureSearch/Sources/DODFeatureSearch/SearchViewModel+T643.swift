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

    /// DUT-622: re-run the current query after a `.error` (REST failure) state.
    /// Wired to the Retry affordance in ``SearchView``'s `.error` empty state; a
    /// transient blip that has since cleared now yields results. Lives here (not
    /// on the main type) for the `file_length` budget; delegates to
    /// ``runImmediateSearch()`` since `performSearch()` is file-private there.
    public func retrySearch() async {
        await runImmediateSearch()
    }

    /// Fire Path A (REST `?search=<query>`) and — only when the user has an
    /// actual category filter chip set — Path B (REST `?categories=` per
    /// matched category, top-2 cap) in parallel via `async let`. Both
    /// short-circuit to `[]` when offline so the existing offline-state
    /// branch in `performSearch()` keeps working without a network round-
    /// trip. Path B's failure does NOT block Path A — each failure path
    /// logs and returns `[]`, so the caller always gets a usable tuple.
    ///
    /// DUT-574: Path B used to fire whenever the *typed query text* happened
    /// to name a WP category (e.g. "beef" → "Beef and Red Meat Recipes"),
    /// firing up to two `?categories=<id>&per_page=100` fetches — up to 200
    /// extra posts — on every finalized plain-text search, then unioning ALL
    /// of them (date-ordered, most NOT matching the query) into the results.
    /// That doubled/tripled the per-query round-trips (slowness) AND polluted
    /// the result list with unrelated recent category posts (the "doesn't
    /// work right" symptom). The category-match fan-out now fires ONLY when a
    /// category filter is actually set (`filters.categoryID != nil`) — a plain
    /// text search makes exactly one primary REST call. Preserved for the
    /// filter-active case so the category-scoped surface still works.
    /// DUT-622: `restFailed` is `true` when the primary REST request actually
    /// threw (vs genuinely returning zero rows). It rides out of the fan-out so
    /// `finishTextSearch` can surface a retryable `.error` state instead of the
    /// misleading `.noResults` dead-end when the online request failed and no
    /// local ingredient fallback covers it. Offline short-circuits to
    /// `restFailed: false` — that path is the `.offline` state's job, not
    /// `.error`'s.
    func fanOutSearchPaths(
        trimmed: String,
        online: Bool
    ) async -> FanOutResult {
        guard online else { return FanOutResult(restResults: [], categoryResults: [], restFailed: false) }
        guard filters.categoryID != nil else {
            // Plain text search: single primary request, no category fan-out.
            let outcome = await fetchTitleSearchOrEmpty(trimmed: trimmed)
            return FanOutResult(restResults: outcome.items, categoryResults: [], restFailed: outcome.failed)
        }
        async let restTask = fetchTitleSearchOrEmpty(trimmed: trimmed)
        async let categoryTask = fetchCategoryMatchesOrEmpty(trimmed: trimmed)
        let (restOutcome, categoryResults) = await (restTask, categoryTask)
        return FanOutResult(
            restResults: restOutcome.items,
            categoryResults: categoryResults,
            restFailed: restOutcome.failed
        )
    }

    /// The fan-out's three outputs bundled (avoids a 3-tuple return). Path A's
    /// title results, Path B's category results, and — DUT-622 — whether the
    /// primary REST request actually FAILED (vs genuinely returning zero).
    struct FanOutResult {
        let restResults: [RecipeListItem]
        let categoryResults: [RecipeListItem]
        let restFailed: Bool
    }

    /// Path A wrapper: REST `?search=<query>` → `[RecipeListItem]`, plus the
    /// existing background cache-write. Errors are logged and return
    /// `(items: [], failed: true)` so the caller's tuple is never the source of
    /// a thrown error — DUT-622: `failed` lets the caller tell an actual REST
    /// FAILURE (retryable `.error`) apart from a genuine zero-result response
    /// (`.noResults`). A successful fetch — even of zero rows — returns
    /// `failed: false`.
    func fetchTitleSearchOrEmpty(trimmed: String) async -> (items: [RecipeListItem], failed: Bool) {
        do {
            let restResults = try await dependencies.search(query: trimmed)
            try? await dependencies.cache(listItems: restResults)
            return (restResults, false)
        } catch {
            DODLog.network.error("search REST failed: \(String(describing: error))")
            return ([], true)
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
    /// The network outcome of a fan-out, bundled so `finishTextSearch` stays
    /// under SwiftLint's parameter-count cap: whether we were `online`, and —
    /// DUT-622 — whether the primary REST request actually FAILED.
    struct NetworkOutcome {
        let online: Bool
        let restFailed: Bool
    }

    func finishTextSearch(
        merged: [RecipeListItem],
        localItems: [RecipeListItem],
        trimmed: String,
        network: NetworkOutcome,
        generation: Int
    ) async {
        // H1: a newer search may have started while we awaited the fan-out.
        guard generation == searchGeneration else { return }
        let titleIDs = Set(merged.map(\.id))
        let ingredientOnly = localItems.filter { !titleIDs.contains($0.id) }

        // True offline state only when BOTH tiers are empty. A local
        // ingredient hit needs no network, so it keeps the user on a results
        // screen even with REST down — the offline-resilience win DUT-11
        // unlocks on top of CL-120's title-precision contract.
        if merged.isEmpty, ingredientOnly.isEmpty, !network.online {
            state = .offline
            items = []
            ingredientItems = []
            return
        }

        // DUT-622: the online REST request FAILED (threw, not "returned zero")
        // and no local ingredient tier covers it. Surface a retryable `.error`
        // instead of falling through to `.noResults` ("No recipes match
        // '<query>'"), which reads as "we searched and found nothing" and offers
        // no recovery. `restFailed` is only ever `true` while `online`, so this
        // never masks the offline branch above.
        if merged.isEmpty, ingredientOnly.isEmpty, network.restFailed {
            state = .error
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

        await applyFiltersAndFinalize(merged: merged, trimmed: trimmed, generation: generation)
    }

    /// Final hop of `performSearch()`: hydrate the filter-support maps,
    /// apply the filter chips, set `items` + `state`, and fire the
    /// recents/telemetry + cook-time hydration tails. Extracted so
    /// `performSearch()` stays under the function-body cap after the
    /// T-643 fan-out tuple was inlined into it.
    func applyFiltersAndFinalize(
        merged: [RecipeListItem],
        trimmed: String,
        generation: Int
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
            // Fetch into locals first; a newer search can supersede us across
            // these awaits, so re-check the generation before committing (H1).
            let categoryIDs = (try? await dependencies.categoryIDs(forRecipeIDs: allIDs)) ?? [:]
            let totalSeconds = (try? await dependencies.totalSeconds(forRecipeIDs: allIDs)) ?? [:]
            let recentlyViewed = (try? await dependencies.recentlyViewedRecipeIDs()) ?? []
            guard generation == searchGeneration else { return }
            lastCategoryIDsByRecipe = categoryIDs
            lastTotalSecondsByRecipe = totalSeconds
            lastRecentlyViewedIDs = recentlyViewed
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
            trimmed: trimmed,
            generation: generation
        )

        // DUT-254: the `recipe_searched` event fires on FINALIZED searches only
        // (Return / keyboard dismissal via `commitRecentSearch`), NOT on every
        // debounced pass — typing "chicken" used to emit ~5 partial-query events
        // ("ch", "chi", …), inflating counts and polluting the query-hash
        // distribution. This per-debounce finalize hop no longer sends it.
        kickOffCookTimeHydrationIfNeeded(against: merged)
    }

    /// US-12 amendment / US-29 amendment / CL-127 (T-649): the
    /// suggestion compute hop. Runs only when the result set is sparse
    /// (< 3 items); clears `didYouMean` otherwise so a follow-up search
    /// that lands a populated result page wipes a stale banner. The
    /// cached-titles fetch is wrapped in `try?` so a cold cache fall-
    /// through degrades to `nil` (engine returns nil on an empty pool,
    /// same outcome).
    func computeDidYouMean(itemCount: Int, trimmed: String, generation: Int) async {
        guard itemCount < Self.didYouMeanThreshold, !trimmed.isEmpty else {
            // DUT-568: a newer search can supersede us before we reach this
            // write; re-check the generation so an older pass doesn't clear a
            // fresh banner (mirrors the H1 guard at +T643:178 / +T637:98).
            guard generation == searchGeneration else { return }
            didYouMean = nil
            return
        }
        let cachedTitles = (try? await dependencies.cachedRecipeTitles()) ?? []
        // DUT-568: re-check after the async cached-titles fetch — a newer
        // search that bumped the generation during that await must not have its
        // banner clobbered by this older pass's suggestion.
        guard generation == searchGeneration else { return }
        didYouMean = SearchSuggestionEngine.suggest(
            query: trimmed,
            cachedTitles: cachedTitles
        )
    }

    /// Send the AC-3.6 SHA-256-hashed query to analytics on each completed
    /// search. T-779 / DUT-85 moved recent-recording out of this path into
    /// ``commitRecentSearch()`` (Return / keyboard dismissal only), so this no
    /// longer persists to the recents store. The finalize hop above calls it.
    /// Relocated here from `SearchViewModel.swift` (file-length relief for the
    /// v2 Surprise Me stored state).
    func sendSearchTelemetry(trimmed: String) async {
        let hash = StringHasher.sha256Hex(trimmed)
        await dependencies.sendSearchTelemetry(queryHash: hash)
    }
}

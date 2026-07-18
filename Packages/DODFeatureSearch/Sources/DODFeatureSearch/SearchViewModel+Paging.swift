import DODDomain
import DODSupport
import Foundation

/// v2 search paging — infinite-scroll paging for the text-search result set.
///
/// The gap this closes: the pipeline (`SearchViewModel+Pipeline`) fetched only
/// `page: 1` of `?search=<query>` and never advanced, so a query with more than
/// one page of hits silently truncated at the first page. This mirrors the
/// Feed's proven `FeedViewModel.loadMoreIfNeeded` + `loadMore` pattern: a
/// near-bottom row appearance arms the next page, a single-flight guard blocks
/// concurrent fetches, the page is deduped by recipe id against everything
/// already shown, and an empty/short page latches the end.
///
/// Scope: only the plain `?search=` TEXT path pages. The Latest-Recipes
/// (`+T637`) surface sets `lastSurface == .latestRecipes` and the category
/// fan-out (Path B) is a filter-scoped one-shot — both are excluded by the
/// guards below. The local ingredient index isn't paged either; only the
/// SERVER content matches from later `?search=` pages extend the "Recipes
/// Using <term>" tier.
///
/// Generation / stale-drop: a new query bumps `searchGeneration` (see
/// `performSearch`), which cancels an in-flight page — `loadMoreResults`
/// captures the generation and re-checks it after every `await`, dropping its
/// appends if a newer query has superseded it. `finishTextSearch` re-arms the
/// page cursor when the fresh page-1 set commits.
extension SearchViewModel {

    /// Reset the infinite-scroll cursor + end latch so a fresh query (or a
    /// Clear) starts paging from page 1 again. The in-flight generation bump the
    /// caller performs is what cancels any page already in flight; this just
    /// re-arms the local cursor state. Called from `clear()`, the short-query
    /// branch of `scheduleSearch`, and `finishTextSearch`'s page-1 commit.
    func resetResultsPaging() {
        searchResultsPage = 1
        searchResultsReachedEnd = false
    }

    /// Near-bottom infinite-scroll trigger, fired from a `.task` on the trailing
    /// result cards (title tier + "Recipes Using" tier). Mirrors
    /// `FeedViewModel.loadMoreIfNeeded(currentItem:)`: it only pages when the
    /// appearing card is among the last `loadMoreTailWindow` combined rows, so
    /// mid-list card recycling never triggers a fetch.
    public func loadMoreResultsIfNeeded(currentItem: RecipeListItem) async {
        guard canLoadMoreResults else { return }
        // The genuine bottom is the tail of the title tier PLUS the ingredient
        // tier that renders beneath it, so a query whose title tier is short but
        // whose "Recipes Using" tier is long still pages when the user reaches
        // the real end.
        let tail = (items + ingredientItems).suffix(Self.loadMoreTailWindow)
        guard tail.contains(where: { $0.id == currentItem.id }) else { return }
        await loadMoreResults()
    }

    /// Whether a next-page fetch is currently permissible: we're showing text
    /// results, a committed query exists, the end isn't latched, and no page is
    /// already in flight. Kept as a computed accessor so both the trigger and
    /// the fetch share one definition.
    var canLoadMoreResults: Bool {
        state == .results
            && lastSurface == .textQuery
            && !lastQuery.isEmpty
            && !searchResultsReachedEnd
            && !isLoadingMoreResults
    }

    /// Fetch the next `?search=` page, append its deduped new hits, and latch the
    /// end on an empty/short page. Guarded single-flight; every mutation after an
    /// `await` re-checks the search generation so a query typed mid-fetch drops
    /// this page's writes instead of appending stale results to the new query.
    func loadMoreResults() async {
        guard canLoadMoreResults else { return }
        let generation = searchGeneration
        let query = lastQuery
        // Don't page while offline — the primary fetch already surfaced whatever
        // the local tiers could, and a failed page would only churn.
        guard await dependencies.isOnline() else { return }
        guard generation == searchGeneration else { return }

        isLoadingMoreResults = true
        defer { isLoadingMoreResults = false }

        let nextPage = searchResultsPage + 1
        do {
            let pageItems = try await dependencies.searchMore(query: query, page: nextPage)
            // A newer query superseded us across the fetch — drop these writes.
            guard generation == searchGeneration else { return }
            try? await dependencies.cache(listItems: pageItems)
            guard generation == searchGeneration else { return }

            // Empty or short page = WP's last page: latch the end so the trigger
            // stops firing. A short page is still appended below before we stop.
            if pageItems.count < Self.searchResultsPageSize {
                searchResultsReachedEnd = true
            }
            searchResultsPage = nextPage
            guard !pageItems.isEmpty else { return }
            await appendPagedResults(pageItems, query: query, generation: generation)
        } catch {
            DODLog.network.error("search loadMore failed: \(String(describing: error))")
            // Mirror the Feed's tolerant tail-failure: a transient page failure
            // must NOT latch `searchResultsReachedEnd` (that would kill paging for
            // the session) — keep the cursor, a later near-bottom appearance
            // retries the same page.
        }
    }

    /// Partition a fetched page into its title + content tiers, dedupe both
    /// against everything already shown (the accumulated title base
    /// `lastMergedRESTOrdering` AND the ingredient tier), append the genuinely
    /// new rows to their respective tiers, and re-project the title tier through
    /// the active filters. Under an active filter the newly appended title ids
    /// are hydrated into the filter-support maps first so they aren't dropped by
    /// the "missing = MISS" rule.
    private func appendPagedResults(
        _ pageItems: [RecipeListItem],
        query: String,
        generation: Int
    ) async {
        let partition = SearchResultMerger.partition(query: query, restResults: pageItems)
        // Dedupe against the full accumulated base (a superset of the visible,
        // possibly-filtered `items`) plus the ingredient tier, so no card repeats
        // across pages or tiers.
        var seen = Set(lastMergedRESTOrdering.map(\.id))
        seen.formUnion(ingredientItems.map(\.id))
        let newTitle = partition.titleMatches.filter { seen.insert($0.id).inserted }
        let newContent = partition.contentMatches.filter { seen.insert($0.id).inserted }

        if !newTitle.isEmpty { lastMergedRESTOrdering.append(contentsOf: newTitle) }
        if !newContent.isEmpty { ingredientItems.append(contentsOf: newContent) }

        // Under an active filter, hydrate the filter-support maps for the newly
        // appended title ids before re-applying (mirrors `applyFiltersAndFinalize`
        // — without it, `filters.apply` would reject uncached ids as MISS).
        if !filters.isAllDefault, !newTitle.isEmpty {
            let newIDs = newTitle.map(\.id)
            let categoryIDs = (try? await dependencies.categoryIDs(forRecipeIDs: newIDs)) ?? [:]
            let totalSeconds = (try? await dependencies.totalSeconds(forRecipeIDs: newIDs)) ?? [:]
            guard generation == searchGeneration else { return }
            lastCategoryIDsByRecipe.merge(categoryIDs) { _, new in new }
            lastTotalSecondsByRecipe.merge(totalSeconds) { _, new in new }
        }

        items = filters.apply(
            to: lastMergedRESTOrdering,
            categoryIDsByRecipe: lastCategoryIDsByRecipe,
            totalSecondsByRecipe: lastTotalSecondsByRecipe,
            recentlyViewedIDs: lastRecentlyViewedIDs
        )
    }
}

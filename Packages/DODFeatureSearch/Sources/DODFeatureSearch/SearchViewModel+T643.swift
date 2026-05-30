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
}

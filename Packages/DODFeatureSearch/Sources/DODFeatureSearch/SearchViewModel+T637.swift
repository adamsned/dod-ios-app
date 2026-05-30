import DODDomain
import DODSupport
import Foundation

/// CL-106 (T-637): the three Search-page fixes — cook-time hydration on
/// cache miss and the "Latest Recipes" Try-pill special-case — split into
/// an extension on `SearchViewModel` so the main view-model file stays
/// under SwiftLint's `file_length` (400-line) cap. The chip-row gating
/// fix is view-only and lives in `SearchView.swift`.
///
/// The Latest-Recipes branch sets `lastSurface = .latestRecipes` so the
/// existing `reapplyFilters()` in the main file knows which base set to
/// re-rank against on a filter mutation; the hydration helper is shared
/// by both the typed-search path (`performSearch`) and the Latest-Recipes
/// path so a filter flip mid-result-set always narrows correctly.
extension SearchViewModel {

    /// US-29 / AC-29.1 amendment / CL-106 (T-637): the "Latest Recipes"
    /// Try-pill special case. Fetches the N most-recent posts via
    /// `dependencies.fetchLatestRecipes(limit:)` and renders the result
    /// set directly — bypassing the text-search path which would search
    /// for the literal string "Latest Recipes" and return garbage (the
    /// phrase appears in many unrelated articles' boilerplate). The
    /// fetch over-fetches by ~1.5x so a few latest-articles-being-articles
    /// still leaves ~N recipes after the post-fetch drop.
    ///
    /// Does NOT persist the term to the recent-searches store (mirrors
    /// the curated-tap exclusion intent from REG-19 / CL-66 / T-670 —
    /// the user did not type a search term, they tapped a discovery
    /// pill). Does NOT send a search-telemetry hash because there is no
    /// query string to hash (AC-3.6 covers text queries; this is a feed
    /// fetch, not a search).
    public func surfaceLatestRecipes(limit: Int = 5) async {
        state = .searching
        guard await dependencies.isOnline() else {
            state = .offline
            items = []
            return
        }
        let overFetch = Int((Double(limit) * 1.5).rounded(.up))
        guard let fetched = await fetchLatestOrFail(overFetch: overFetch) else {
            return
        }
        try? await dependencies.cache(listItems: fetched)

        // Trim back to the requested limit. The article-vs-recipe
        // discriminator is a JSON-LD parse outcome, so we don't know the
        // kind for uncached fresh-fetch items here. The detail-screen
        // path classifies on open per US-37 / AC-37.2.
        let trimmed = Array(fetched.prefix(limit))
        await applyLatestRecipes(trimmed: trimmed)
    }

    /// Helper: wrap the dependency fetch + error-to-offline mapping in a
    /// nullable return so the parent stays under SwiftLint's
    /// `function_body_length` cap.
    private func fetchLatestOrFail(overFetch: Int) async -> [RecipeListItem]? {
        do {
            return try await dependencies.fetchLatestRecipes(limit: overFetch)
        } catch {
            DODLog.network.error("surfaceLatestRecipes failed: \(String(describing: error))")
            state = .offline
            items = []
            return nil
        }
    }

    /// Helper: stitch the trimmed latest-recipes set into the same
    /// `lastMergedRESTOrdering` / filter-application path the typed-search
    /// flow uses, so subsequent filter mutations re-apply correctly.
    private func applyLatestRecipes(trimmed: [RecipeListItem]) async {
        items = trimmed
        lastQuery = ""
        lastSurface = .latestRecipes
        lastMergedRESTOrdering = trimmed
        lastMergedLocalOrdering = []
        let allIDs = trimmed.map(\.id)
        lastCategoryIDsByRecipe =
            (try? await dependencies.categoryIDs(forRecipeIDs: allIDs)) ?? [:]
        lastTotalSecondsByRecipe =
            (try? await dependencies.totalSeconds(forRecipeIDs: allIDs)) ?? [:]
        lastRecentlyViewedIDs =
            (try? await dependencies.recentlyViewedRecipeIDs()) ?? []

        let filtered = filters.apply(
            to: trimmed,
            categoryIDsByRecipe: lastCategoryIDsByRecipe,
            totalSecondsByRecipe: lastTotalSecondsByRecipe,
            recentlyViewedIDs: lastRecentlyViewedIDs
        )
        items = filtered
        state = filtered.isEmpty ? .noResults : .results

        kickOffCookTimeHydrationIfNeeded(against: trimmed)
    }
}

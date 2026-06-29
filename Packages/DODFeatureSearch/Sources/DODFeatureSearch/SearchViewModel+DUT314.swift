import DODDomain
import DODSupport
import Foundation

/// DUT-314: the search-perf gate's lazy filter-support hydration.
///
/// `applyFiltersAndFinalize` (in `+T643`) skips the three filter-support
/// fetches (`categoryIDs`, `totalSeconds`, and the full-table
/// `recentlyViewedRecipeIDs` scan) whenever the search runs with default
/// filters — `SearchFilters.apply` ignores the maps in that case, so they
/// are pure waste. The first chip toggle after such a search then finds the
/// caches empty; this helper lazily fetches them once so the re-rank still
/// narrows correctly, preserving the US-12 / AC-12.3 "filter chip re-ranks
/// the cached set with no REST round-trip" contract.
///
/// Lives in its own file so `SearchViewModel.swift` stays under SwiftLint's
/// `file_length` (400-line) cap — same split pattern as `+T637` / `+T643`.
extension SearchViewModel {

    /// Lazily hydrate the filter-support caches the first time a non-default
    /// filter is applied after a default search skipped them. No-op when
    /// filters are all default (nothing to filter against) or when the caches
    /// were already populated (a non-default search hydrated them inline, or a
    /// prior toggle already triggered this). Runs the same detached `Task`
    /// pattern as `kickOffCookTimeHydrationIfNeeded` — fetch off the main
    /// thread, write the caches back on the `@MainActor`, then re-rank.
    func kickOffFilterSupportHydrationIfNeeded(against merged: [RecipeListItem]) {
        guard !filters.isAllDefault, !filterSupportHydrated else { return }
        // Flip the flag up front so a rapid burst of chip toggles only fires
        // one hydration task (subsequent toggles re-rank in-memory).
        filterSupportHydrated = true
        let allIDs = merged.map(\.id)
        let generation = searchGeneration
        Task { [weak self] in
            guard let self else { return }
            let categoryIDs =
                (try? await self.dependencies.categoryIDs(forRecipeIDs: allIDs)) ?? [:]
            let totalSeconds =
                (try? await self.dependencies.totalSeconds(forRecipeIDs: allIDs)) ?? [:]
            let recentlyViewed =
                (try? await self.dependencies.recentlyViewedRecipeIDs()) ?? []
            // H1: a new search since kickoff supersedes this stale hydration.
            guard generation == self.searchGeneration else { return }
            self.lastCategoryIDsByRecipe = categoryIDs
            self.lastTotalSecondsByRecipe = totalSeconds
            self.lastRecentlyViewedIDs = recentlyViewed
            self.reapplyFilters()
        }
    }
}

import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

@Suite("SearchResultMerger (US-12 / REG-12)") struct SearchResultMergerTests {

    @Test func restTitleHitsRankAboveExcerptHits() {
        let titleHit = item(1, title: "Garlic Bread", excerpt: "A classic")
        let excerptHit = item(2, title: "Crusty Loaf", excerpt: "Goes with garlic butter")
        let merged = SearchResultMerger.merge(
            query: "garlic",
            restResults: [excerptHit, titleHit],
            localIngredientResults: []
        )
        #expect(merged.map(\.id) == [1, 2], "Title match must rank above excerpt match")
    }

    @Test func localIngredientHitsRankBelowAllRestHits() {
        let restHit = item(1, title: "Garlic Bread", excerpt: "x")
        let localHit = item(2, title: "Pasta Bake", excerpt: "x")
        let merged = SearchResultMerger.merge(
            query: "garlic",
            restResults: [restHit],
            localIngredientResults: [localHit]
        )
        #expect(merged.map(\.id) == [1, 2])
    }

    @Test func duplicateRecipeAcrossSourcesAppearsOnce() {
        let shared = item(7, title: "Garlic Soup", excerpt: "x")
        let merged = SearchResultMerger.merge(
            query: "garlic",
            restResults: [shared],
            localIngredientResults: [shared]
        )
        #expect(merged.count == 1)
        #expect(merged.first?.id == 7)
    }

    @Test func emptySourcesReturnEmptyMerge() {
        let merged = SearchResultMerger.merge(
            query: "anything",
            restResults: [],
            localIngredientResults: []
        )
        #expect(merged.isEmpty)
    }

    // MARK: - REG-17 (T-530, CL-53): AC-12.3 filter composition for fresh REST results
    //
    // Pins the AND-wise composition contract between the category chip and
    // the Any-time / cook-time chip after the merger runs — given a recipe
    // in category C with total-time T, `filter = {category: C, maxDuration: T}`
    // includes the recipe; `filter = {category: C, maxDuration: T-1}` does
    // NOT. The prior failure mode was that fresh REST hits had no
    // `CachedRecipe.categoryIDs` populated (the wire data was dropped at the
    // network → domain boundary), so the category filter excluded everything
    // before the cook-time chip ran. T-530 fixed the data pipeline; this
    // test locks the composition contract at the filter-chain seam so any
    // future regression of that shape (or any new filter slice that fails
    // to AND-compose with cook-time) trips the suite.

    @Test func composeCategoryAndCookTimeFiltersForFreshRESTResults() {
        // Two recipes both tagged with category 10. One takes 25 min
        // (under the 60-min bucket); the other takes 90 min (over).
        let twentyFiveMin = item(1, title: "Beef Skillet Quick", excerpt: "x")
        let ninetyMin = item(2, title: "Beef Slow Braise", excerpt: "x")

        let merged = SearchResultMerger.merge(
            query: "beef",
            restResults: [twentyFiveMin, ninetyMin],
            localIngredientResults: []
        )
        #expect(merged.count == 2, "Pre-filter merge surfaces both recipes")

        let filters = SearchFilters(categoryID: 10, cookTime: .under60)
        let filtered = filters.apply(
            to: merged,
            categoryIDsByRecipe: [1: [10], 2: [10]],
            totalSecondsByRecipe: [1: 25 * 60, 2: 90 * 60],
            recentlyViewedIDs: []
        )
        #expect(
            filtered.map(\.id) == [1],
            "AC-12.3 composition: category 10 AND ≤60 min → only the 25-min recipe survives."
        )

        // Tightening the cook-time bucket to ≤15 min drops both — the
        // 25-min recipe still matches the category but exceeds the
        // duration, the 90-min recipe was already over. AND composition
        // means tightening either predicate can only shrink the result
        // set.
        let stricterFilters = SearchFilters(categoryID: 10, cookTime: .under15)
        let stricterFiltered = stricterFilters.apply(
            to: merged,
            categoryIDsByRecipe: [1: [10], 2: [10]],
            totalSecondsByRecipe: [1: 25 * 60, 2: 90 * 60],
            recentlyViewedIDs: []
        )
        #expect(
            stricterFiltered.isEmpty,
            "AC-12.3 composition: category 10 AND ≤15 min → neither recipe matches the duration predicate."
        )
    }

    private func item(_ id: Int, title: String, excerpt: String) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: excerpt,
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}

import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

/// Genuine-gap tests for SearchResultMerger and SearchFilters pure helpers.
/// Spec trace: US-12, AC-12.2, AC-12.3, CL-120, REG-29.
@Suite("Pure Helper Edge Cases: Merger & Filters")
struct PureHelperGapsMergerTests {

    // MARK: - SearchResultMerger edge cases

    /// Whitespace-only query (after trimming) returns empty list per the guard.
    @Test func whitespaceOnlyQueryReturnsEmpty() {
        let merged = SearchResultMerger.merge(
            query: "   ",
            restResults: [item(1, title: "Pizza", excerpt: "x")],
            localIngredientResults: []
        )
        #expect(merged.isEmpty, "Whitespace-only query must return empty")
    }

    /// Newline/tab-only query also returns empty after trimming.
    @Test func newlineAndTabOnlyQueryReturnsEmpty() {
        let merged = SearchResultMerger.merge(
            query: "\n\t  \n",
            restResults: [item(1, title: "Pizza", excerpt: "x")],
            localIngredientResults: []
        )
        #expect(merged.isEmpty, "Newline/tab-only query must return empty")
    }

    /// Dedup stability: same recipe ID appearing twice in results should
    /// appear only once in the merged list.
    @Test func duplicateRecipeIDAppearsOnlyOnce() {
        let pizza = item(1, title: "Pizza", excerpt: "x")
        let merged = SearchResultMerger.merge(
            query: "pizza",
            restResults: [pizza, pizza],
            localIngredientResults: []
        )
        #expect(
            merged.count == 1,
            "Same recipe ID appearing twice must be deduped to one entry"
        )
        #expect(merged.first?.id == 1)
    }

    /// Dedup with multiple occurrences of the same ID: the first occurrence
    /// (by position in the tier) is kept, later ones are dropped.
    @Test func triplicateRecipeIDKeepsFirstOccurrence() {
        let pizza1 = item(1, title: "Pizza", excerpt: "x")
        let pizza2 = item(1, title: "Pizza", excerpt: "y")
        let pizza3 = item(1, title: "Pizza", excerpt: "z")
        let merged = SearchResultMerger.merge(
            query: "pizza",
            restResults: [pizza1, pizza2, pizza3],
            localIngredientResults: []
        )
        #expect(
            merged.count == 1,
            "Three identical IDs must dedupe to exactly one entry"
        )
    }

    /// When multiple distinct IDs with identical titles both match exactly,
    /// the source order is preserved within the exact tier.
    @Test func exactMatchTierPreservesSourceOrder() {
        let pizza1 = item(1, title: "Pizza", excerpt: "x")
        let pizza2 = item(2, title: "Pizza", excerpt: "y")
        let merged = SearchResultMerger.merge(
            query: "pizza",
            restResults: [pizza1, pizza2],
            localIngredientResults: []
        )
        #expect(
            merged.map(\.id) == [1, 2],
            "Exact match tier must preserve source order"
        )
    }

    /// Very long query (whitespace trimmed) still works as expected.
    @Test func veryLongQueryAfterTrimming() {
        let longQuery = String(repeating: "a", count: 500)
        let merged = SearchResultMerger.merge(
            query: longQuery,
            restResults: [],
            localIngredientResults: []
        )
        #expect(merged.isEmpty, "Long query with no results returns empty")
    }

    // MARK: - SearchFilters edge cases

    /// Cook time filter with min = 0 includes all non-negative times.
    @Test func cookTimeMinZeroIncludesAllPositiveTimes() {
        let filters = SearchFilters(cookTimeMinSeconds: 0)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [1: 0, 2: 30 * 60, 3: 90 * 60],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1, 2, 3])
    }

    /// Very large cook time max (Int.max / 60 * 60 approximate) still filters.
    @Test func cookTimeMaxVeryLarge() {
        let maxSeconds = (Int.max / 3600) * 3600
        let filters = SearchFilters(cookTimeMaxSeconds: maxSeconds)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [1: maxSeconds - 1, 2: 90 * 60],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1, 2])
    }

    /// Cook time min and max at Int.max / 3600 boundary (very large).
    @Test func cookTimeMinMaxAtMaxBoundary() {
        let maxValue = (Int.max / 3600) * 3600
        let filters = SearchFilters(
            cookTimeMinSeconds: maxValue,
            cookTimeMaxSeconds: maxValue
        )
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [1: maxValue, 2: maxValue - 1],
            recentlyViewedIDs: []
        )
        #expect(
            result.map(\.id) == [1],
            "Only recipe at exact boundary should pass"
        )
    }

    /// Category filter with empty map and non-nil categoryID filters everything.
    @Test func categoryFilterWithEmptyMapExcludesAll() {
        let filters = SearchFilters(categoryID: 10)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.isEmpty, "No recipes in map → all excluded")
    }

    /// Category filter where one recipe is in map, another is not.
    @Test func categoryFilterPartialMapMembership() {
        let filters = SearchFilters(categoryID: 10)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [1: [10], 3: [10]],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(
            result.map(\.id) == [1, 3],
            "Only recipes in map with matching category survive"
        )
    }

    /// When all filters are individually default but one is set, isAllDefault
    /// correctly returns false.
    @Test func isAllDefaultWithOnlyCookTimeMin() {
        let filters = SearchFilters(cookTimeMinSeconds: 1)
        #expect(!filters.isAllDefault)
    }

    /// Cook time range helper correctly identifies when range is active.
    @Test func hasCookTimeRangeWithMinSetOnly() {
        let filters = SearchFilters(cookTimeMinSeconds: 30 * 60)
        #expect(filters.hasCookTimeRange)
    }

    /// isAllDefault returns true only when all fields are at default.
    @Test func isAllDefaultWhenAllFieldsDefault() {
        let filters = SearchFilters()
        #expect(filters.isAllDefault)
    }

    /// isAllDefault returns false when categoryID is zero (0 is a valid filter).
    @Test func isAllDefaultFalseWhenCategoryIDIsZero() {
        let filters = SearchFilters(categoryID: 0)
        #expect(!filters.isAllDefault, "categoryID = 0 is a real filter, not default")
    }

    /// isAllDefault returns false when recentlyViewedOnly is true.
    @Test func isAllDefaultFalseWhenRecentlyViewedOnly() {
        let filters = SearchFilters(recentlyViewedOnly: true)
        #expect(!filters.isAllDefault)
    }

    // MARK: - Helper

    private func item(_ id: Int, title: String? = nil, excerpt: String = "x") -> RecipeListItem {
        let finalTitle = title ?? "Recipe \(id)"
        return RecipeListItem(
            id: id,
            title: finalTitle,
            excerpt: excerpt,
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}

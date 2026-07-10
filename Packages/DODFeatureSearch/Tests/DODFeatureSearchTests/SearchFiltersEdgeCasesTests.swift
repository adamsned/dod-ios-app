import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

@Suite("SearchFilters (Edge Cases)")
struct SearchFiltersEdgeCasesTests {

    // MARK: - Empty items array edge cases

    @Test func emptyItemsArrayWithCategoryFilterReturnsEmpty() {
        let filters = SearchFilters(categoryID: 10)
        let result = filters.apply(
            to: [],
            categoryIDsByRecipe: [1: [10]],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.isEmpty)
    }

    @Test func emptyItemsArrayWithCookTimeFilterReturnsEmpty() {
        let filters = SearchFilters(cookTimeMinSeconds: 30 * 60, cookTimeMaxSeconds: 60 * 60)
        let result = filters.apply(
            to: [],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [1: 45 * 60],
            recentlyViewedIDs: []
        )
        #expect(result.isEmpty)
    }

    @Test func emptyItemsArrayWithRecentlyViewedFilterReturnsEmpty() {
        let filters = SearchFilters(recentlyViewedOnly: true)
        let result = filters.apply(
            to: [],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: [1]
        )
        #expect(result.isEmpty)
    }

    // MARK: - CookTimeFormatter boundary edge cases

    @Test func cookTimeFormatterHandlesZeroSeconds() {
        let label = CookTimeFormatter.label(seconds: 0)
        #expect(label == "0 min")
    }

    @Test func cookTimeFormatterHandlesOneSecond() {
        let label = CookTimeFormatter.label(seconds: 1)
        #expect(label == "0 min")
    }

    @Test func cookTimeFormatterHandles59Seconds() {
        let label = CookTimeFormatter.label(seconds: 59)
        #expect(label == "0 min")
    }

    @Test func cookTimeFormatterHandles60Seconds() {
        let label = CookTimeFormatter.label(seconds: 60)
        #expect(label == "1 min")
    }

    @Test func cookTimeFormatterHandles3599Seconds() {
        // 59 min 59 sec
        let label = CookTimeFormatter.label(seconds: 3599)
        #expect(label == "59 min")
    }

    @Test func cookTimeFormatterHandles3600Seconds() {
        let label = CookTimeFormatter.label(seconds: 3600)
        #expect(label == "1 hr")
    }

    @Test func cookTimeFormatterHandles3601Seconds() {
        // 1 hr 0 min 1 sec → rounds down to 1 hr
        let label = CookTimeFormatter.label(seconds: 3601)
        #expect(label == "1 hr")
    }

    @Test func cookTimeFormatterHandles7200Seconds() {
        // 2 hours
        let label = CookTimeFormatter.label(seconds: 7200)
        #expect(label == "2 hr")
    }

    @Test func cookTimeFormatterHandles14400Seconds() {
        // 4 hours
        let label = CookTimeFormatter.label(seconds: 14400)
        #expect(label == "4 hr")
    }

    // MARK: - Cook time chip label edge cases

    @Test func cookTimeChipLabelWithZeroMinAndMax() {
        let label = cookTimeChipLabel(min: 0, max: 0)
        #expect(label == "0 min")
    }

    @Test func cookTimeChipLabelWithOneMinuteMin() {
        let label = cookTimeChipLabel(min: 60, max: nil)
        #expect(label == "1 min or more")
    }

    @Test func cookTimeChipLabelWith59MinutesMax() {
        let label = cookTimeChipLabel(min: nil, max: 59 * 60)
        #expect(label == "59 min or less")
    }

    @Test func cookTimeChipLabelWithBoundary3599() {
        let label = cookTimeChipLabel(min: 3599, max: 3599)
        #expect(label == "59 min")
    }

    @Test func cookTimeChipLabelWithBoundary3600() {
        let label = cookTimeChipLabel(min: 3600, max: 3600)
        #expect(label == "1 hr")
    }

    @Test func cookTimeChipLabelWithBoundary3601() {
        let label = cookTimeChipLabel(min: 3601, max: 3601)
        #expect(label == "1 hr")
    }

    // MARK: - hasCookTimeRange property edge cases

    @Test func hasCookTimeRangeWithBothNil() {
        let filters = SearchFilters()
        #expect(!filters.hasCookTimeRange)
    }

    @Test func hasCookTimeRangeWithOnlyMin() {
        let filters = SearchFilters(cookTimeMinSeconds: 30 * 60)
        #expect(filters.hasCookTimeRange)
    }

    @Test func hasCookTimeRangeWithOnlyMax() {
        let filters = SearchFilters(cookTimeMaxSeconds: 60 * 60)
        #expect(filters.hasCookTimeRange)
    }

    @Test func hasCookTimeRangeWithBothSet() {
        let filters = SearchFilters(
            cookTimeMinSeconds: 30 * 60,
            cookTimeMaxSeconds: 60 * 60
        )
        #expect(filters.hasCookTimeRange)
    }

    @Test func hasCookTimeRangeWithZeroMin() {
        let filters = SearchFilters(cookTimeMinSeconds: 0)
        #expect(filters.hasCookTimeRange)
    }

    // MARK: - isAllDefault property edge cases

    @Test func isAllDefaultWithAllNilAndFalse() {
        let filters = SearchFilters()
        #expect(filters.isAllDefault)
    }

    @Test func isAllDefaultWithCategoryID() {
        let filters = SearchFilters(categoryID: 10)
        #expect(!filters.isAllDefault)
    }

    @Test func isAllDefaultWithCookTimeMin() {
        let filters = SearchFilters(cookTimeMinSeconds: 30 * 60)
        #expect(!filters.isAllDefault)
    }

    @Test func isAllDefaultWithCookTimeMax() {
        let filters = SearchFilters(cookTimeMaxSeconds: 60 * 60)
        #expect(!filters.isAllDefault)
    }

    @Test func isAllDefaultWithRecentlyViewedOnly() {
        let filters = SearchFilters(recentlyViewedOnly: true)
        #expect(!filters.isAllDefault)
    }

    @Test func isAllDefaultWithCategoryIDZero() {
        let filters = SearchFilters(categoryID: 0)
        #expect(!filters.isAllDefault, "categoryID = 0 is still a non-default filter")
    }

    // MARK: - Category filtering edge cases

    @Test func categoryIDEdgeCaseZero() {
        let filters = SearchFilters(categoryID: 0)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [1: [0], 2: [1]],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1])
    }

    @Test func categoryFilterWithRecipeHavingEmptyCategoryList() {
        let filters = SearchFilters(categoryID: 10)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [1: [10], 2: []],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1], "Recipe 2 has empty category list → exclude")
    }

    @Test func categoryFilterWithMultipleCategoriesPerRecipe() {
        let filters = SearchFilters(categoryID: 10)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [
                1: [10, 20, 30],
                2: [20, 30],
                3: [10],
            ],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1, 3])
    }

    @Test func recipeIDNotInCategoryIDMap() {
        let filters = SearchFilters(categoryID: 10)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.isEmpty, "Neither recipe in map → both excluded")
    }

    // MARK: - Cook time filtering edge cases

    @Test func cookTimeMinWithZeroSecondsIncludesAllTimes() {
        let filters = SearchFilters(cookTimeMinSeconds: 0)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [
                1: 0,
                2: 30 * 60,
                3: 90 * 60,
            ],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1, 2, 3])
    }

    @Test func cookTimeMaxWithZeroSecondsIncludesOnlyZero() {
        let filters = SearchFilters(cookTimeMaxSeconds: 0)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [
                1: 0,
                2: 30 * 60,
                3: 90 * 60,
            ],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1])
    }

    @Test func cookTimeMinAndMaxAtSameBoundary() {
        let filters = SearchFilters(
            cookTimeMinSeconds: 60,
            cookTimeMaxSeconds: 60
        )
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [
                1: 59,
                2: 60,
                3: 61,
            ],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [2])
    }

    @Test func cookTimeMissingFromTotalSecondsMapWhenRangeActive() {
        let filters = SearchFilters(cookTimeMinSeconds: 30 * 60)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [1: 20 * 60, 3: 45 * 60],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [3], "Recipe 1 too short (20 min < 30 min), recipe 2 missing → exclude both")
    }

    // MARK: - Helper

    private func item(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "x",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}

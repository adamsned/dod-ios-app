import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

@Suite("SearchFilters (Composition Edge Cases)")
struct SearchFiltersCompositionTests {

    // MARK: - Recently viewed edge cases

    @Test func recentlyViewedWithEmptyRecentlyViewedSet() {
        let filters = SearchFilters(recentlyViewedOnly: true)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.isEmpty)
    }

    @Test func recentlyViewedWithRecipeNotInSet() {
        let filters = SearchFilters(recentlyViewedOnly: true)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: [2, 4]
        )
        #expect(result.map(\.id) == [2])
    }

    @Test func recentlyViewedWithAllRecipesInSet() {
        let filters = SearchFilters(recentlyViewedOnly: true)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: [1, 2, 3]
        )
        #expect(result.map(\.id) == [1, 2, 3])
    }

    // MARK: - Multi-filter composition edge cases

    @Test func allFiltersActiveWithMixedResults() {
        let filters = SearchFilters(
            categoryID: 10,
            cookTimeMinSeconds: 30 * 60,
            cookTimeMaxSeconds: 90 * 60,
            recentlyViewedOnly: true
        )
        let result = filters.apply(
            to: [item(1), item(2), item(3), item(4), item(5)],
            categoryIDsByRecipe: [
                1: [10],  // right category
                2: [10],  // right category
                3: [10],  // right category
                4: [20],  // wrong category
                5: [10],  // right category
            ],
            totalSecondsByRecipe: [
                1: 20 * 60,  // too short
                2: 45 * 60,  // in range
                3: 100 * 60,  // too long
                4: 45 * 60,  // in range but wrong category
                5: 60 * 60,  // in range
            ],
            recentlyViewedIDs: [2, 3, 4, 5]  // 1 not viewed, 4 in set
        )
        // 1 — cat ok, time too short → OUT
        // 2 — cat ok, time ok, recent ok → IN
        // 3 — cat ok, time too long, recent ok → OUT
        // 4 — wrong category → OUT
        // 5 — cat ok, time ok, recent ok → IN
        #expect(result.map(\.id) == [2, 5])
    }

    @Test func categoryAndCookTimeWithMissingData() {
        let filters = SearchFilters(
            categoryID: 10,
            cookTimeMinSeconds: 30 * 60
        )
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [1: [10], 2: [10], 3: [10]],
            totalSecondsByRecipe: [1: 20 * 60, 3: 50 * 60],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [3], "Recipe 2 missing cook time → exclude")
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

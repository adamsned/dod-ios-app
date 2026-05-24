import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

@Suite("SearchFilters (US-12 / AC-12.3)") struct SearchFiltersTests {

    @Test func defaultFiltersAdmitEverything() {
        let filters = SearchFilters()
        let items = [item(1), item(2)]
        let result = filters.apply(
            to: items,
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1, 2])
    }

    @Test func categoryFilterDropsItemsLackingTheCategory() {
        let filters = SearchFilters(categoryID: 10)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [1: [10, 20], 2: [30]],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1])
    }

    @Test func categoryFilterTreatsUnknownAsMiss() {
        let filters = SearchFilters(categoryID: 10)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [1: [10]],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1], "Recipe 2 had no category data → exclude")
    }

    @Test func cookTimeBucketAdmitsAtMostThatTotal() {
        let filters = SearchFilters(cookTime: .under30)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [
                1: 10 * 60,  // 10 min — under 30
                2: 30 * 60,  // exactly 30 — under 30
                3: 45 * 60,  // 45 — over 30
            ],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1, 2])
    }

    @Test func overHourBucketIsTheStrictComplement() {
        let filters = SearchFilters(cookTime: .overHour)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [1: 60 * 60, 2: 61 * 60],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [2])
    }

    @Test func filtersCompose() {
        let filters = SearchFilters(
            categoryID: 10,
            cookTime: .under30,
            recentlyViewedOnly: true
        )
        let result = filters.apply(
            to: [item(1), item(2), item(3), item(4)],
            categoryIDsByRecipe: [1: [10], 2: [10], 3: [10], 4: [20]],
            totalSecondsByRecipe: [1: 10 * 60, 2: 45 * 60, 3: 5 * 60, 4: 5 * 60],
            recentlyViewedIDs: [1, 3]
        )
        // 1 — cat ok, time ok, recent ok → IN
        // 2 — cat ok, time too long → OUT
        // 3 — cat ok, time ok, recent ok → IN
        // 4 — wrong cat → OUT
        #expect(result.map(\.id) == [1, 3])
    }

    @Test func recentlyViewedFilterExcludesUnopened() {
        let filters = SearchFilters(recentlyViewedOnly: true)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [:],
            recentlyViewedIDs: [2]
        )
        #expect(result.map(\.id) == [2])
    }

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

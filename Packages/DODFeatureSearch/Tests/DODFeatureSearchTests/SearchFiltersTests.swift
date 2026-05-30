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

    // MARK: - Cook-time range (CL-122 / T-644 — min/max model)

    /// Max-only narrows to items at or under the cap (boundary inclusive).
    /// Replaces the pre-T-644 `cookTimeBucketAdmitsAtMostThatTotal` test
    /// — the wheel-picker's "Any-on-min, 30-min-on-max" selection lands
    /// here, and the contract this pins is the new REG-31 max-only path.
    @Test func cookTimeMaxOnlyNarrowsAtOrUnderCap() {
        let filters = SearchFilters(cookTimeMaxSeconds: 30 * 60)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [
                1: 10 * 60,  // 10 min — under 30
                2: 30 * 60,  // exactly 30 — under 30 (inclusive)
                3: 45 * 60,  // 45 — over 30
            ],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1, 2])
    }

    /// Min-only narrows to items at or above the floor (boundary inclusive).
    /// Replaces the pre-T-644 `overHourBucketIsTheStrictComplement` test —
    /// the new "1 hr or more" chip state asserts the same shape with the
    /// inclusive boundary rule.
    @Test func cookTimeMinOnlyNarrowsAtOrAboveFloor() {
        let filters = SearchFilters(cookTimeMinSeconds: 60 * 60)
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [
                1: 59 * 60,  // 59 min — under
                2: 60 * 60,  // exactly 60 — included (inclusive)
                3: 61 * 60,  // 61 min — included
            ],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [2, 3])
    }

    /// Both bounds set returns items inside the closed interval [min, max].
    /// New L1 contract — the chip state the wheel picker is built for
    /// ("30 min–1 hr 30 min") that the pre-T-644 bucket model couldn't express.
    @Test func cookTimeMinAndMaxReturnsItemsInsideInterval() {
        let filters = SearchFilters(
            cookTimeMinSeconds: 60 * 60,
            cookTimeMaxSeconds: 120 * 60
        )
        let result = filters.apply(
            to: [item(1), item(2), item(3), item(4)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [
                1: 30 * 60,  // 30 min — below floor
                2: 60 * 60,  // exactly 60 — included
                3: 90 * 60,  // 90 min — included
                4: 121 * 60,  // over ceiling
            ],
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [2, 3])
    }

    /// Inverted range (min > max) is silently empty since no totalSeconds
    /// can satisfy both predicates. Pinned per CL-122's "no UI enforcement
    /// — the empty-results state handles it" trade-off.
    @Test func cookTimeInvertedRangeReturnsEmpty() {
        let filters = SearchFilters(
            cookTimeMinSeconds: 60 * 60,
            cookTimeMaxSeconds: 30 * 60
        )
        let result = filters.apply(
            to: [item(1), item(2), item(3)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [
                1: 10 * 60,
                2: 45 * 60,
                3: 90 * 60,
            ],
            recentlyViewedIDs: []
        )
        #expect(result.isEmpty)
    }

    /// Missing `totalSeconds` for an item is treated as a MISS when the
    /// cook-time range is active — same "missing = MISS" rule as the
    /// pre-T-644 bucket model (the T-637 / CL-106 hydration path is what
    /// fills the gap on cache miss; that contract is **unchanged**).
    @Test func cookTimeMissingTotalSecondsIsStillMiss() {
        let filters = SearchFilters(cookTimeMaxSeconds: 30 * 60)
        let result = filters.apply(
            to: [item(1), item(2)],
            categoryIDsByRecipe: [:],
            totalSecondsByRecipe: [1: 20 * 60],  // 2 missing
            recentlyViewedIDs: []
        )
        #expect(result.map(\.id) == [1])
    }

    @Test func filtersCompose() {
        let filters = SearchFilters(
            categoryID: 10,
            cookTimeMaxSeconds: 30 * 60,
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

    // MARK: - Chip-label helper (CL-122 / T-644)

    /// Pins the four-state chip label format: both nil → "Any time";
    /// only min → "<min> or more"; only max → "<max> or less"; both →
    /// "<min>–<max>" (en-dash); min == max → "<value>".
    @Test func cookTimeChipLabelComputesAllFourStates() {
        #expect(cookTimeChipLabel(min: nil, max: nil) == "Any time")
        #expect(cookTimeChipLabel(min: 30 * 60, max: nil) == "30 min or more")
        #expect(cookTimeChipLabel(min: 90 * 60, max: nil) == "1 hr 30 min or more")
        #expect(cookTimeChipLabel(min: nil, max: 45 * 60) == "45 min or less")
        #expect(cookTimeChipLabel(min: nil, max: 60 * 60) == "1 hr or less")
        #expect(cookTimeChipLabel(min: 30 * 60, max: 90 * 60) == "30 min–1 hr 30 min")
        #expect(cookTimeChipLabel(min: 45 * 60, max: 45 * 60) == "45 min")
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

// MARK: - CookTimeFormatter (CL-122 / T-644)

@Suite("CookTimeFormatter (CL-122 / T-644)") struct CookTimeFormatterTests {

    @Test func labelBelowOneHourRendersMinutes() {
        #expect(CookTimeFormatter.label(seconds: 30 * 60) == "30 min")
    }

    @Test func labelAtOneHourRendersHrLabel() {
        #expect(CookTimeFormatter.label(seconds: 3600) == "1 hr")
    }

    @Test func labelOverOneHourWithLeftoverRendersHrAndMin() {
        #expect(CookTimeFormatter.label(seconds: 90 * 60) == "1 hr 30 min")
    }

    @Test func labelAtExactMultipleOfHourRendersHoursOnly() {
        #expect(CookTimeFormatter.label(seconds: 2 * 3600) == "2 hr")
    }

    @Test func labelAtFourHoursRendersHoursOnly() {
        #expect(CookTimeFormatter.label(seconds: 4 * 3600) == "4 hr")
    }
}

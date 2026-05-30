import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

@Suite("SearchResultMerger (US-12 / REG-12 / CL-120 / REG-29 / T-642)")
struct SearchResultMergerTests {

    @Test func restTitleHitsRankAboveOtherTitleHits() {
        // Exact match ("Garlic") ranks above substring match
        // ("Garlic Bread") under CL-120's tier sort.
        let exactHit = item(1, title: "Garlic", excerpt: "x")
        let substringHit = item(2, title: "Garlic Bread", excerpt: "x")
        let merged = SearchResultMerger.merge(
            query: "garlic",
            restResults: [substringHit, exactHit],
            localIngredientResults: []
        )
        #expect(merged.map(\.id) == [1, 2], "Exact tier must rank above substring tier")
    }

    @Test func bodyOnlyMatchesAreDropped() {
        // CL-120 / T-642: the merger now applies a title-precision
        // filter. A REST hit whose title does NOT contain the query
        // (in any tier — exact / substring / fuzzy) is dropped, no
        // matter what WP returned it for. This is the verbatim
        // false-positive contract from the round-9 backlog entry.
        let titleHit = item(1, title: "Cast Iron Skillet Nachos", excerpt: "x")
        let bodyOnly = item(2, title: "Cast Iron Bacon Wrapped Pickles", excerpt: "x")
        let merged = SearchResultMerger.merge(
            query: "nachos",
            restResults: [titleHit, bodyOnly],
            localIngredientResults: []
        )
        #expect(
            merged.map(\.id) == [1],
            "Body-only matches must not surface — title-precision contract (CL-120)"
        )
    }

    @Test func localIngredientHitsAreDroppedInV1OfCL120() {
        // CL-120 v1 deferral: the local-ingredient surface is dropped
        // from the merged set for v1 of the Nacho Bug fix — title
        // precision is the user's contract; ingredient-search ships
        // back as a labeled tier in the broader "Make search way
        // better" follow-up.
        let restTitleHit = item(1, title: "Garlic Bread", excerpt: "x")
        let localOnly = item(2, title: "Pasta Bake", excerpt: "garlic via ingredient")
        let merged = SearchResultMerger.merge(
            query: "garlic",
            restResults: [restTitleHit],
            localIngredientResults: [localOnly]
        )
        #expect(merged.map(\.id) == [1], "Local ingredient pass is v1-deferred per CL-120")
    }

    @Test func duplicateRecipeAcrossSourcesAppearsOnce() {
        let shared = item(7, title: "Garlic Soup", excerpt: "x")
        let merged = SearchResultMerger.merge(
            query: "garlic",
            restResults: [shared, shared],
            localIngredientResults: []
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

    @Test func fuzzyTitleHitsSurfaceBelowExactAndSubstring() {
        // Plural-swap fuzzy: query "nachos" → title "Super Nacho Dip"
        // (singular nacho) lands in the fuzzy tier (the substring
        // tier fails because the literal "nachos" with the s does
        // NOT appear in the title). Mixed with an exact + a
        // substring hit, the fuzzy entry sorts last.
        let exact = item(1, title: "Nachos", excerpt: "x")
        let substring = item(2, title: "Tater Tot Nachos", excerpt: "x")
        let fuzzy = item(3, title: "Super Nacho Dip", excerpt: "x")
        let merged = SearchResultMerger.merge(
            query: "nachos",
            restResults: [fuzzy, substring, exact],
            localIngredientResults: []
        )
        #expect(merged.map(\.id) == [1, 2, 3], "Tier order: exact, substring, fuzzy")
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

        // CL-122 / T-644: bucket model retired — pre-T-644 `cookTime:
        // .under60` rewrites to `cookTimeMaxSeconds: 60 * 60` (and
        // `under15` → `15 * 60`). AND-composition contract is unchanged;
        // the new model just expresses the cap as a real range bound.
        let filters = SearchFilters(categoryID: 10, cookTimeMaxSeconds: 60 * 60)
        let filtered = filters.apply(
            to: merged,
            categoryIDsByRecipe: [1: [10], 2: [10]],
            totalSecondsByRecipe: [1: 25 * 60, 2: 90 * 60],
            recentlyViewedIDs: []
        )
        #expect(
            filtered.map(\.id) == [1],
            "AC-12.3 composition: category 10 AND max-60 min → only the 25-min recipe survives."
        )

        // Tightening the cook-time cap to 15 min drops both — the
        // 25-min recipe still matches the category but exceeds the
        // duration, the 90-min recipe was already over. AND composition
        // means tightening either predicate can only shrink the result
        // set.
        let stricterFilters = SearchFilters(categoryID: 10, cookTimeMaxSeconds: 15 * 60)
        let stricterFiltered = stricterFilters.apply(
            to: merged,
            categoryIDsByRecipe: [1: [10], 2: [10]],
            totalSecondsByRecipe: [1: 25 * 60, 2: 90 * 60],
            recentlyViewedIDs: []
        )
        #expect(
            stricterFiltered.isEmpty,
            "AC-12.3 composition: category 10 AND max-15 min → neither recipe matches the duration predicate."
        )
    }

    // MARK: - CL-120 / T-642 lock: the live-API truth for `?search=nachos`
    //
    // Per the round-9 diagnosis, the live REST returns exactly 4 posts
    // whose titles contain "nacho" plus a long tail of body-only false
    // positives. The pipeline after the per_page bump + title-precision
    // filter must surface exactly the 4 title-bearing posts and drop
    // the false positives. This test pins the contract end-to-end at
    // the merger seam using the verbatim title strings from the live
    // diagnosis fixture in the prompt.

    @Test func nachoBugFixSurfacesFourKnownTitleMatches() {
        let knownNachoTitles = [
            (524, "Super Nacho Dip"),
            (274, "Tater Tot Nachos"),
            (5016, "Pulled Pork Nachos"),
            (736, "Cast Iron Skillet Nachos"),
        ]
        let knownFalsePositives = [
            (101, "Cast Iron Bacon Wrapped Pickles"),
            (102, "Skillet Birria"),
            (103, "Skillet Chocolate Chip Cookie"),
            (104, "Tequila Lime Chicken"),
        ]
        let candidates =
            knownNachoTitles.map { item($0.0, title: $0.1, excerpt: "x") }
            + knownFalsePositives.map { item($0.0, title: $0.1, excerpt: "nachos in body") }

        let merged = SearchResultMerger.merge(
            query: "nachos",
            restResults: candidates,
            localIngredientResults: []
        )

        #expect(merged.count == 4, "Exactly the 4 known nacho-titled posts must survive")
        #expect(
            Set(merged.map(\.id)) == Set(knownNachoTitles.map(\.0)),
            "Surviving ids must be 524, 274, 5016, 736 (the live-API truth for ?search=nachos)"
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

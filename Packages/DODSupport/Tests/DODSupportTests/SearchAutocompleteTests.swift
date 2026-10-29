import Foundation
import Testing

@testable import DODSupport

/// v2 Search overhaul (2/3) — coverage for the pure type-ahead ranking helper.
@Suite("SearchAutocomplete")
struct SearchAutocompleteTests {

    private let pool = [
        "Buttermilk Biscuits",
        "Blueberry Buttermilk Pancakes",
        "Beef Chili",
        "Garlic Butter Shrimp",
        "Garlic Bread",
    ]

    @Test func wholeTitlePrefixRanksAboveWordPrefix() {
        // "butter": "Buttermilk Biscuits" starts the whole title (tier 0);
        // "Blueberry Buttermilk Pancakes" only has a WORD starting with it
        // (tier 1); "Garlic Butter Shrimp" likewise (tier 1, later in pool).
        let result = SearchAutocomplete.suggestions(query: "butter", titles: pool, limit: 6)
        #expect(
            result == [
                "Buttermilk Biscuits",
                "Blueberry Buttermilk Pancakes",
                "Garlic Butter Shrimp",
            ]
        )
    }

    @Test func limitCapsTheResultCount() {
        let result = SearchAutocomplete.suggestions(query: "butter", titles: pool, limit: 2)
        #expect(result == ["Buttermilk Biscuits", "Blueberry Buttermilk Pancakes"])
    }

    @Test func nonMatchingTitlesAreExcluded() {
        let result = SearchAutocomplete.suggestions(query: "chili", titles: pool, limit: 6)
        #expect(result == ["Beef Chili"])
    }

    @Test func substringMatchRanksBelowPrefixes() {
        // "read" appears only mid-word ("Bread") — a pure substring (tier 2).
        let titles = ["Reading Nook Snacks", "Garlic Bread"]
        let result = SearchAutocomplete.suggestions(query: "read", titles: titles, limit: 6)
        #expect(result == ["Reading Nook Snacks", "Garlic Bread"])
    }

    @Test func oneCharQueryYieldsNothing() {
        #expect(SearchAutocomplete.suggestions(query: "b", titles: pool, limit: 6).isEmpty)
    }

    @Test func emptyPoolYieldsNothing() {
        #expect(SearchAutocomplete.suggestions(query: "butter", titles: [], limit: 6).isEmpty)
    }

    @Test func duplicateTitlesCollapseToFirst() {
        let titles = ["Buttermilk Biscuits", "buttermilk biscuits", "Buttermilk Pancakes"]
        let result = SearchAutocomplete.suggestions(query: "butter", titles: titles, limit: 6)
        #expect(result == ["Buttermilk Biscuits", "Buttermilk Pancakes"])
    }

    @Test func matchIsDiacriticAndCaseInsensitive() {
        // Shares TitleSearchMatcher.normalize, so "jalapeno" matches "Jalapeño".
        let titles = ["Jalapeño Poppers"]
        let result = SearchAutocomplete.suggestions(query: "jalapeno", titles: titles, limit: 6)
        #expect(result == ["Jalapeño Poppers"])
    }
}

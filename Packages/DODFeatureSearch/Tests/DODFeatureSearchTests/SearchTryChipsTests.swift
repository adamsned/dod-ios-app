import Foundation
import Testing

@testable import DODFeatureSearch

/// L1 unit tests for the curated "Try Searching" chip pool
/// (``SearchTryChips``) — v2 Search overhaul (3/3).
///
/// Locks the pool's shape (exactly 100 unique raw-lowercase terms) and the
/// display-casing mapper (Title Case per CL-305 + the two special cases),
/// which together underpin every rendered chip.
@Suite("SearchTryChips (v2 Search overhaul 3/3)") struct SearchTryChipsTests {

    // MARK: - Pool shape

    @Test func pool_has_exactly_100_entries() {
        #expect(SearchTryChips.pool.count == 100)
    }

    @Test func pool_entries_are_all_unique() {
        #expect(Set(SearchTryChips.pool).count == SearchTryChips.pool.count)
    }

    @Test func pool_entries_are_raw_lowercase_and_trimmed() {
        for term in SearchTryChips.pool {
            #expect(term == term.lowercased(), "pool term not lowercase: \(term)")
            #expect(
                term == term.trimmingCharacters(in: .whitespaces),
                "pool term has surrounding whitespace: \(term)"
            )
            #expect(!term.isEmpty, "pool contains an empty term")
        }
    }

    @Test func latest_recipes_is_not_in_the_pool() {
        // Latest Recipes is the special pinned chip, not one of the 100.
        #expect(!SearchTryChips.pool.contains("latest recipes"))
        #expect(SearchTryChips.latestRecipes.isLatestRecipes)
        #expect(SearchTryChips.latestRecipes.query.isEmpty)
        #expect(SearchTryChips.latestRecipes.display == "Latest Recipes")
    }

    // MARK: - Display mapper

    @Test func display_mapper_title_cases_simple_terms() {
        #expect(SearchTryChips.displayName(for: "ground beef") == "Ground Beef")
        #expect(SearchTryChips.displayName(for: "peach cobbler") == "Peach Cobbler")
        #expect(SearchTryChips.displayName(for: "lasagna") == "Lasagna")
    }

    @Test func display_mapper_lowercases_small_words_between_first_and_last() {
        #expect(SearchTryChips.displayName(for: "mac and cheese") == "Mac and Cheese")
        #expect(SearchTryChips.displayName(for: "biscuits and gravy") == "Biscuits and Gravy")
        #expect(SearchTryChips.displayName(for: "chicken and dumplings") == "Chicken and Dumplings")
    }

    @Test func display_mapper_preserves_apostrophes() {
        #expect(SearchTryChips.displayName(for: "shepherd's pie") == "Shepherd's Pie")
    }

    @Test func display_mapper_applies_special_cases() {
        #expect(SearchTryChips.displayName(for: "tex mex") == "Tex-Mex")
        #expect(SearchTryChips.displayName(for: "30 minute") == "30 Minute")
    }

    @Test func chip_keeps_raw_query_while_title_casing_display() {
        let chip = SearchTryChips.chip(for: "ground beef")
        #expect(chip.query == "ground beef")
        #expect(chip.display == "Ground Beef")
        #expect(!chip.isLatestRecipes)

        // The hyphenated / display-only special cases keep the raw query.
        let tex = SearchTryChips.chip(for: "tex mex")
        #expect(tex.query == "tex mex")
        #expect(tex.display == "Tex-Mex")
    }

    @Test func every_pool_term_maps_to_a_nonempty_display() {
        for term in SearchTryChips.pool {
            let display = SearchTryChips.displayName(for: term)
            #expect(!display.isEmpty, "empty display for \(term)")
            // No em dashes in copy (feedback rule).
            #expect(!display.contains("\u{2014}"), "display contains em dash: \(display)")
        }
    }
}

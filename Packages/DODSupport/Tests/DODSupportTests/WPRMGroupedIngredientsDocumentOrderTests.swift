import Foundation
import Testing

@testable import DODSupport

/// Regression tests locking the DUT-557 document-order contract of
/// ``WPRMRecipeCardParser/ingredientsInDocumentOrder(in:)``.
///
/// The method takes the INNER body of the `<div class="wprm-recipe-container">`
/// (the card string already sliced by the container extractor) and returns
/// plain-text ingredient lines in a single document-order pass over the
/// `wprm-recipe-ingredient-group` `<div>`s.
///
/// DUT-557 regression: the pre-DUT-557 implementation ran two separate scans —
/// line rows first, then header-only group names — and concatenated the results.
/// A header-only group that PRECEDED a line-row group in the DOM was therefore
/// moved to the END of the output list. The post-DUT-557 single-pass fix
/// preserves the document order of every group exactly.
///
/// Tests use `@testable import DODSupport` because
/// `ingredientsInDocumentOrder(in:)` is an internal `static func`.
@Suite("WPRMRecipeCardParser ingredientsInDocumentOrder (DUT-557)")
struct WPRMGroupedIngredientsDocumentOrderTests {

    // MARK: - DUT-557 core regression

    /// A header-only group — a `wprm-recipe-ingredient-group` `<div>` with only a
    /// group-name `<h4>` and NO `<li>` rows — that appears BEFORE a line-row
    /// group must remain first in the output. Pre-DUT-557, the separate
    /// `rows + headerOnlyGroupNames` concatenation moved it to the end.
    @Test func headerOnlyGroupPrecedingLineRowGroupPreservesDocumentOrder() {
        let card = """
            <div class="wprm-recipe-ingredient-group">
            <h4 class="wprm-recipe-ingredient-group-name">1 bay leaf</h4>
            </div>
            <div class="wprm-recipe-ingredient-group">
            <h4 class="wprm-recipe-ingredient-group-name">For the base</h4>
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">2 cups flour</li>
            </ul>
            </div>
            """
        let result = WPRMRecipeCardParser.ingredientsInDocumentOrder(in: card)
        // "1 bay leaf" (header-only group) must appear BEFORE "2 cups flour"
        // (the line-row group that follows it in the DOM).
        #expect(result == ["1 bay leaf", "2 cups flour"])
    }

    // MARK: - Two line-row groups

    /// When both groups carry `<li class="wprm-recipe-ingredient">` rows, all
    /// rows are emitted in document order: group 1 rows before group 2 rows.
    /// The group-name `<h4>` labels are dropped (they are section labels, not
    /// ingredients, when line rows are present).
    @Test func twoLineRowGroupsEmittedInDocumentOrder() {
        let card = """
            <div class="wprm-recipe-ingredient-group">
            <h4 class="wprm-recipe-ingredient-group-name">For the sauce</h4>
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">2 cups tomato sauce</li>
            </ul>
            </div>
            <div class="wprm-recipe-ingredient-group">
            <h4 class="wprm-recipe-ingredient-group-name">For the seasoning</h4>
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">1 tsp salt</li>
            </ul>
            </div>
            """
        let result = WPRMRecipeCardParser.ingredientsInDocumentOrder(in: card)
        #expect(result == ["2 cups tomato sauce", "1 tsp salt"])
    }

    // MARK: - Bare flat card (no group divs)

    /// When the card has NO `wprm-recipe-ingredient-group` `<div>`s — only a
    /// bare `<ul class="wprm-recipe-ingredients">` with `<li>` rows — the
    /// function falls back to a flat line-row scan, returning rows in document
    /// order. This is the dominant WPRM shape; DUT-557 must leave it unchanged.
    @Test func flatCardWithNoGroupDivsFallsBackToLineRowScan() {
        let card = """
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">3 lbs ground beef</li>
            <li class="wprm-recipe-ingredient">1 onion</li>
            </ul>
            """
        let result = WPRMRecipeCardParser.ingredientsInDocumentOrder(in: card)
        #expect(result == ["3 lbs ground beef", "1 onion"])
    }

    // MARK: - Empty / no-ingredient card

    /// A card body with neither `wprm-recipe-ingredient-group` `<div>`s nor
    /// `wprm-recipe-ingredient` `<li>` rows returns an empty array.
    @Test func cardWithNoIngredientsYieldsEmptyResult() {
        let card = #"<h2 class="wprm-recipe-name">Just a title</h2>"#
        let result = WPRMRecipeCardParser.ingredientsInDocumentOrder(in: card)
        #expect(result.isEmpty)
    }
}

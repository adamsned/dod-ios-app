import Foundation
import Testing

@testable import DODSupport

/// Unit tests for ``WPRMRecipeCardParser`` (DUT-42).
///
/// All fixtures here are **trimmed-but-real** WP Recipe Maker markup captured
/// from `dutchovendaddy.com` on 2026-06-04 — the structural `<li>` / `<h4>` /
/// `<span>` shapes WPRM server-renders into `<div class="wprm-recipe-container">`.
/// The parser is the per-field fallback the JSON-LD parser reaches for when a
/// post ships a `Recipe` node that omits `recipeIngredient` /
/// `recipeInstructions`.
@Suite("WPRMRecipeCardParser (DUT-42)") struct WPRMRecipeCardParserTests {

    // MARK: - Standard ingredient line rows (the common case)

    /// The dominant WPRM shape: each ingredient is an `<li class="wprm-recipe-ingredient">`
    /// with amount / unit / name / notes spans, preceded by a checkbox-container
    /// span carrying a screen-reader ballot-box glyph (`&#9634;`) that MUST NOT
    /// leak into the text. Real markup from `dutch-oven-awesome-chili` (recipe 1569).
    @Test func extractsStandardIngredientLineRows() {
        let html = """
            <div class="wprm-recipe-container">
            <div id="recipe-1569-ingredients" class="wprm-recipe-ingredients-container">
            <h3 class="wprm-recipe-header wprm-recipe-ingredients-header">Ingredients</h3>
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient" style="list-style-type: none;" data-uid="0"><span class="wprm-checkbox-container"><input type="checkbox" id="wprm-checkbox-1" class="wprm-checkbox" aria-label="&nbsp;3 lbs lean ground beef"><label for="wprm-checkbox-1" class="wprm-checkbox-label"><span class="sr-only screen-reader-text wprm-screen-reader-text">&#9634; </span></label></span><span class="wprm-recipe-ingredient-amount">3</span> <span class="wprm-recipe-ingredient-unit">lbs</span> <span class="wprm-recipe-ingredient-name">lean ground beef</span></li>
            <li class="wprm-recipe-ingredient" style="list-style-type: none;" data-uid="1"><span class="wprm-checkbox-container"><input type="checkbox" id="wprm-checkbox-2" class="wprm-checkbox" aria-label="&nbsp;1 onion diced"><label for="wprm-checkbox-2" class="wprm-checkbox-label"><span class="sr-only screen-reader-text wprm-screen-reader-text">&#9634; </span></label></span><span class="wprm-recipe-ingredient-amount">1</span> <span class="wprm-recipe-ingredient-name">onion</span> <span class="wprm-recipe-ingredient-notes wprm-recipe-ingredient-notes-faded">diced</span></li>
            </ul>
            </div>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["3 lbs lean ground beef", "1 onion diced"])
        // The screen-reader ballot-box glyph (&#9634; -> U+25A2) must never
        // leak into the text — the checkbox-container subtree is dropped first.
        #expect(card.ingredients.allSatisfy { !$0.contains("\u{25A2}") })
    }

    // MARK: - Instruction rows

    /// Each step is an `<li class="wprm-recipe-instruction">` wrapping a
    /// `<div class="wprm-recipe-instruction-text">`. Real markup from
    /// `dutch-oven-awesome-chili` (recipe 1569).
    @Test func extractsInstructionRows() {
        let html = """
            <div class="wprm-recipe-container">
            <div id="recipe-1569-instructions" class="wprm-recipe-instructions-container">
            <h3 class="wprm-recipe-header wprm-recipe-instructions-header">Instructions</h3>
            <ul class="wprm-recipe-instructions">
            <li id="wprm-recipe-1569-step-0-0" class="wprm-recipe-instruction" style="list-style-type: decimal;"><div class="wprm-recipe-instruction-text" style="margin-bottom: 5px;"><span style="display: block;">Heat the Dutch oven over medium-high heat</span></div></li>
            <li id="wprm-recipe-1569-step-0-1" class="wprm-recipe-instruction" style="list-style-type: decimal;"><div class="wprm-recipe-instruction-text" style="margin-bottom: 5px;"><span style="display: block;">Crumble in the ground beef; stir.</span></div></li>
            </ul>
            </div>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(
            card.instructions == ["Heat the Dutch oven over medium-high heat", "Crumble in the ground beef; stir."]
        )
    }

    // MARK: - Group-name-only ingredients (the 7 Can Soup shape, DUT-42)

    /// The exact shape that triggers DUT-42 on `dutch-oven-7-can-soup`: the
    /// WPRM card has NO `<li class="wprm-recipe-ingredient">` rows at all — the
    /// author entered each ingredient as a `<h4 class="wprm-recipe-ingredient-group-name">`
    /// group header. With no line rows present, the group names ARE the
    /// ingredients. Real markup from `dutch-oven-7-can-soup` (recipe 3921).
    @Test func fallsBackToGroupNamesWhenNoLineRows() {
        let html = """
            <div class="wprm-recipe-container">
            <div id="recipe-3921-ingredients" class="wprm-recipe-ingredients-container">
            <h3 class="wprm-recipe-header wprm-recipe-ingredients-header">Ingredients</h3>
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-group-name wprm-recipe-ingredient-group-name wprm-block-text-bold">no-bean chili</h4></div>
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-group-name wprm-recipe-ingredient-group-name wprm-block-text-bold">pinto beans, undrained</h4></div>
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-group-name wprm-recipe-ingredient-group-name wprm-block-text-bold">black beans, undrained</h4></div>
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-group-name wprm-recipe-ingredient-group-name wprm-block-text-bold">sweet corn</h4></div>
            </div>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(
            card.ingredients == ["no-bean chili", "pinto beans, undrained", "black beans, undrained", "sweet corn"]
        )
    }

    /// When BOTH line rows and group-name headers are present (a grouped
    /// recipe with real ingredient rows), the line rows win and the group
    /// names are NOT emitted as ingredients — they are section labels, not
    /// ingredient lines, so including them would duplicate/pollute the list.
    @Test func prefersLineRowsOverGroupNamesWhenBothPresent() {
        let html = """
            <div class="wprm-recipe-container">
            <div class="wprm-recipe-ingredients-container">
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-ingredient-group-name">For the sauce</h4>
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-amount">2</span> <span class="wprm-recipe-ingredient-unit">cups</span> <span class="wprm-recipe-ingredient-name">tomato sauce</span></li>
            </ul></div>
            </div>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["2 cups tomato sauce"])
    }

    // MARK: - Entity decoding + whitespace

    /// HTML entities in row text are decoded and whitespace collapsed, matching
    /// the JSON-LD path's ``HTMLSanitizer/plainText(from:)`` normalization.
    @Test func decodesEntitiesAndCollapsesWhitespace() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-amount">1</span> <span class="wprm-recipe-ingredient-name">salt &amp; pepper</span></li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["1 salt & pepper"])
    }

    // MARK: - Empty / absent card

    /// No WPRM container at all → empty result (the JSON-LD parser keeps
    /// whatever it already had — empty stays empty, no crash).
    @Test func returnsEmptyWhenNoCardPresent() {
        let card = WPRMRecipeCardParser.parse(html: "<html><body><p>no recipe card</p></body></html>")
        #expect(card.ingredients.isEmpty)
        #expect(card.instructions.isEmpty)
    }

    /// A card with neither ingredients nor instructions yields empty lists.
    @Test func returnsEmptyForCardWithNoRowsOrGroups() {
        let html = """
            <div class="wprm-recipe-container">
            <h2 class="wprm-recipe-name">Just a title</h2>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients.isEmpty)
        #expect(card.instructions.isEmpty)
    }
}

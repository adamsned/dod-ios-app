import Foundation
import Testing

@testable import DODSupport

/// DUT-554 regression tests for ``WPRMRecipeCardParser``'s instructions-region
/// step scan: the DUT-544 slice dropped ALL steps when the instructions heading
/// wasn't an `<h2>` in the original six-marker list. Split out of
/// `WPRMRecipeCardParserTests` so both files stay under SwiftLint's
/// `file_length` / `type_body_length` caps.
///
/// Fixtures are trimmed-but-real Gutenberg/WPRM markup — the
/// `<ol class="…is-style-circle-number-list…">` "How to Make" step shape plus
/// the surrounding `<h2>` / `<h3>` section headings the region scan anchors on.
@Suite("WPRMRecipeCardParser step-region scan (DUT-554)")
struct WPRMRecipeCardParserStepRegionTests {

    /// DUT-554: the steps sit under an `<h3 class="…">Directions</h3>` sub-heading
    /// (WPRM/Gutenberg posts frequently use `<h3>` for the steps heading, not
    /// `<h2>`). The region scan must also consider `<h3>`, so the steps are
    /// recovered — pre-DUT-554 an `<h3>` heading yielded ZERO steps. A styled
    /// non-step list under a LATER `<h3>` ("Tips") stays out of the region.
    @Test func recoversStepsUnderH3DirectionsHeading() {
        let html = """
            <html><body>
            <div class="entry-content">
            <h3 class="wp-block-heading">Directions</h3>
            <ol class="wp-block-list is-style-circle-number-list"><li><strong>Step 1: Brown.</strong> Sear the beef.</li></ol>
            <ol class="wp-block-list is-style-circle-number-list"><li><strong>Step 2: Simmer.</strong> Add the cans and cook.</li></ol>
            <h3 class="wp-block-heading">Tips</h3>
            <ol class="wp-block-list is-style-circle-number-list"><li>Use a heavy Dutch oven.</li></ol>
            <div class="wprm-recipe-container">
            <div class="wprm-recipe-ingredients-container">
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-ingredient-group-name">ground beef</h4></div>
            </div>
            </div>
            </div>
            </body></html>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["ground beef"])
        #expect(card.instructions.count == 2)
        #expect(card.instructions[0].localizedCaseInsensitiveContains("Brown"))
        #expect(card.instructions[1].localizedCaseInsensitiveContains("Simmer"))
        #expect(!card.instructions.contains { $0.localizedCaseInsensitiveContains("heavy Dutch oven") })
    }

    /// DUT-554: the steps sit under an `<h2>Method</h2>` heading — one of the
    /// heading variants the broadened ``instructionsHeadingMarkers`` now covers
    /// (pre-DUT-554 only "how to make/cook/prepare", "instructions",
    /// "directions", "step-by-step" matched, so "Method" yielded ZERO steps).
    @Test func recoversStepsUnderH2MethodHeading() {
        let html = """
            <html><body>
            <div class="entry-content">
            <h2 class="wp-block-heading">Method</h2>
            <ol class="wp-block-list is-style-circle-number-list"><li><strong>Step 1: Prep.</strong> Chop the onion.</li></ol>
            <ol class="wp-block-list is-style-circle-number-list"><li><strong>Step 2: Cook.</strong> Simmer until tender.</li></ol>
            <h2 class="wp-block-heading">Notes</h2>
            <ol class="wp-block-list is-style-circle-number-list"><li>Leftovers keep three days.</li></ol>
            <div class="wprm-recipe-container">
            <div class="wprm-recipe-ingredients-container">
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-ingredient-group-name">onion</h4></div>
            </div>
            </div>
            </div>
            </body></html>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["onion"])
        #expect(card.instructions.count == 2)
        #expect(card.instructions[0].localizedCaseInsensitiveContains("Prep"))
        #expect(card.instructions[1].localizedCaseInsensitiveContains("Cook"))
        #expect(!card.instructions.contains { $0.localizedCaseInsensitiveContains("Leftovers") })
    }

    /// DUT-544 hold (re-verified after DUT-554 broadened the scan): a styled
    /// non-step `<ol>` ("Tips") under a LATER heading must NOT be swept into the
    /// steps when the real steps sit under a matched instructions heading. The
    /// region-scoping is what keeps this fixed — even though the broadened marker
    /// list and `<h3>` scan widen what anchors a region, a MATCHED heading still
    /// scopes the region to its own section.
    @Test func styledTipsListNotPollutedWhenRealStepsUnderInstructionsHeading() {
        let html = """
            <html><body>
            <div class="entry-content">
            <h2 class="wp-block-heading">Instructions</h2>
            <ol class="wp-block-list is-style-circle-number-list"><li><strong>Step 1: Mix.</strong> Combine everything.</li></ol>
            <ol class="wp-block-list is-style-circle-number-list"><li><strong>Step 2: Bake.</strong> 30 minutes at 350.</li></ol>
            <h2 class="wp-block-heading">Expert Tips</h2>
            <ol class="wp-block-list is-style-circle-number-list"><li>Line the oven with foil for easy cleanup.</li></ol>
            <ol class="wp-block-list is-style-circle-number-list"><li>Double the batch — it freezes well.</li></ol>
            <div class="wprm-recipe-container">
            <div class="wprm-recipe-ingredients-container">
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-ingredient-group-name">flour</h4></div>
            </div>
            </div>
            </div>
            </body></html>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.instructions.count == 2)
        #expect(card.instructions[0].localizedCaseInsensitiveContains("Mix"))
        #expect(card.instructions[1].localizedCaseInsensitiveContains("Bake"))
        #expect(!card.instructions.contains { $0.localizedCaseInsensitiveContains("foil") })
        #expect(!card.instructions.contains { $0.localizedCaseInsensitiveContains("freezes well") })
    }

    /// DUT-554 last resort: NO instructions heading matched, but the page carries
    /// EXACTLY ONE `is-style-circle-number-list` numbered group. Rather than
    /// returning a step-less recipe, the lone unambiguous numbered list is used
    /// as the steps.
    @Test func usesSoleNumberedListWhenNoInstructionsHeading() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>Just some intro prose with no steps heading at all.</p>
            <ol class="wp-block-list is-style-circle-number-list"><li><strong>Step 1: Dump.</strong> Empty the cans in.</li><li><strong>Step 2: Simmer.</strong> Cook 15 minutes.</li></ol>
            <div class="wprm-recipe-container">
            <div class="wprm-recipe-ingredients-container">
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-ingredient-group-name">black beans</h4></div>
            </div>
            </div>
            </div>
            </body></html>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["black beans"])
        #expect(card.instructions.count == 2)
        #expect(card.instructions[0].localizedCaseInsensitiveContains("Dump"))
        #expect(card.instructions[1].localizedCaseInsensitiveContains("Simmer"))
    }

    /// DUT-544 → DUT-554: with NO instructions heading anchoring them but
    /// MULTIPLE styled numbered lists present, the fallback still returns empty —
    /// we won't guess which un-anchored `<ol>` is the steps.
    @Test func returnsEmptyWhenNoInstructionsHeadingAndMultipleLists() {
        let html = """
            <html><body>
            <div class="entry-content">
            <h2 class="wp-block-heading">Substitutions</h2>
            <ol class="wp-block-list is-style-circle-number-list"><li>Swap black beans for kidney beans.</li></ol>
            <ol class="wp-block-list is-style-circle-number-list"><li>Swap corn for hominy.</li></ol>
            <div class="wprm-recipe-container">
            <div class="wprm-recipe-ingredients-container">
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-ingredient-group-name">black beans</h4></div>
            </div>
            </div>
            </div>
            </body></html>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["black beans"])
        #expect(card.instructions.isEmpty)
    }
}

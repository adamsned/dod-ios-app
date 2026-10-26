import Foundation
import Testing

@testable import DODSupport

/// Unit tests for instruction images in ``WPRMRecipeCardParser`` (DUT-170).
@Suite("WPRMRecipeCardParser Step Images (DUT-170)")
struct WPRMRecipeCardParserStepImageTests {

    /// Tests that instruction images are properly extracted from each step.
    @Test func extractsInstructionImages() {
        let html = """
            <div class="wprm-recipe-container">
            <div id="recipe-1569-instructions" class="wprm-recipe-instructions-container">
            <h3 class="wprm-recipe-header wprm-recipe-instructions-header">Instructions</h3>
            <ul class="wprm-recipe-instructions">
            <li id="wprm-recipe-1569-step-0-0" class="wprm-recipe-instruction" style="list-style-type: decimal;"><div class="wprm-recipe-instruction-text" style="margin-bottom: 5px;"><span style="display: block;">Sear</span></div><div class="wprm-recipe-instruction-image"><img src="https://e.com/a.jpg"></div></li>
            <li id="wprm-recipe-1569-step-0-1" class="wprm-recipe-instruction" style="list-style-type: decimal;"><div class="wprm-recipe-instruction-text" style="margin-bottom: 5px;"><span style="display: block;">Cook</span></div></li>
            <li id="wprm-recipe-1569-step-0-2" class="wprm-recipe-instruction" style="list-style-type: decimal;"><div class="wprm-recipe-instruction-text" style="margin-bottom: 5px;"><span style="display: block;">Serve</span></div><div class="wprm-recipe-instruction-image"><img src="http://e.com/b.jpg"></div></li>
            </ul>
            </div>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.instructions.count == 3)
        #expect(card.instructionImages == [URL(string: "https://e.com/a.jpg"), nil, nil])
    }
}

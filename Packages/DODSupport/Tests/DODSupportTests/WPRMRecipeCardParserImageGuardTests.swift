import Foundation
import Testing

@testable import DODSupport

/// DUT-170 regression guard: a failed or missing step image degrades to
/// text-only at the parser level.
@Suite("WPRMRecipeCardParser Instruction Image Guards")
struct WPRMRecipeCardParserImageGuardTests {

    @Test func instructionImagesStayAlignedWhenARowIsBlank() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-instructions">
            <li class="wprm-recipe-instruction">
              <div class="wprm-recipe-instruction-text">Mix</div>
              <img src="https://example.com/a.jpg">
            </li>
            <li class="wprm-recipe-instruction"></li>
            <li class="wprm-recipe-instruction">
              <div class="wprm-recipe-instruction-text">Bake</div>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.instructions.count == 2)
        #expect(card.instructionImages.count == 2)
        #expect(card.instructionImages[0] == URL(string: "https://example.com/a.jpg"))
        #expect(card.instructionImages[1] == nil)
    }

    @Test func relativeAndDataImageSourcesAreIgnored() {
        #expect(WPRMRecipeCardParser.firstImageSource(in: "<img src=\"/wp-content/a.jpg\">") == nil)
        #expect(WPRMRecipeCardParser.firstImageSource(in: "<img src=\"data:image/png;base64,AAA\">") == nil)
    }

    @Test func imgWithoutSrcIsNil() {
        #expect(WPRMRecipeCardParser.firstImageSource(in: "<img alt=\"x\">") == nil)
    }

    @Test func noCardMeansEmptyImages() {
        #expect(WPRMRecipeCardParser.parse(html: "<p>hi</p>").instructionImages.isEmpty)
    }
}

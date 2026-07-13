import Foundation
import Testing

@testable import DODSupport

/// Adversarial/malformed HTML robustness tests for ``WPRMRecipeCardParser``.
///
/// These tests ensure the parser degrades gracefully when encountering
/// malformed, nested, or edge-case HTML structures that untrusted web
/// content might contain. The parser must never crash — it either extracts
/// valid text or returns empty results.
@Suite("WPRMRecipeCardParser Adversarial Robustness")
struct WPRMRecipeCardParserAdversarialTests {

    // MARK: - Nested structures

    /// An ingredient row containing a nested `<ul><li>` list inside.
    /// The parser should plain-text the entire body, including nested
    /// list items, and emit a single ingredient line.
    @Test func extractsTextFromNestedListsInsideIngredientRow() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-amount">1</span>
              <ul><li>nested item</li></ul>
              <span class="wprm-recipe-ingredient-name">complex ingredient</span>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // The nested list content gets plain-texted and included.
        #expect(card.ingredients.count == 1)
        #expect(card.ingredients[0].contains("complex ingredient"))
        #expect(card.ingredients[0].contains("nested item"))
    }

    /// Multiple nested `<span class="wprm-checkbox-container">` layers.
    /// The parser removes only the FIRST checkbox-container it encounters,
    /// but should still extract clean text even if nesting is odd.
    @Test func handlesMultipleNestedCheckboxContainers() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-checkbox-container">
                <span class="wprm-checkbox-container">
                  <input type="checkbox">
                </span>
              </span>
              <span class="wprm-recipe-ingredient-name">salt</span>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["salt"])
    }

    // MARK: - Whitespace edge cases

    /// An ingredient row whose body contains only whitespace (spaces, tabs,
    /// newlines). After plain-texting, the result is empty and should be
    /// filtered out of the final list.
    @Test func filtersOutWhitespaceOnlyIngredientRows() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">

            </li>
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-name">flour</span>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // Only the flour ingredient; the whitespace-only row is dropped.
        #expect(card.ingredients == ["flour"])
    }

    /// A container div whose body is only whitespace.
    /// Should return empty ingredients and instructions.
    @Test func returnsEmptyForWhitespaceOnlyContainer() {
        let html = """
            <div class="wprm-recipe-container">


            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients.isEmpty)
        #expect(card.instructions.isEmpty)
    }

    // MARK: - Class attribute word-boundary matching

    /// A `<div>` with a class attribute containing "wprm-recipe-ingredient"
    /// as a SUBSTRING of a longer token (e.g., "wprm-recipe-ingredient-container")
    /// should NOT match the token "wprm-recipe-ingredient" — the match must be
    /// word-boundary aware.
    @Test func classTokenSubstringDoesNotMatch() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredient-container">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-name">valid</span>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // The <ul> has the substring but not the token, so the parser
        // falls back to a flat <li> scan and finds the row.
        #expect(card.ingredients == ["valid"])
    }

    /// An ingredient group name with a class that is a substring match.
    /// `class="wprm-recipe-ingredient-group-header"` contains
    /// "wprm-recipe-ingredient-group-name" as a substring but not as a token.
    @Test func ingredientGroupNameSubstringDoesNotMatch() {
        let html = """
            <div class="wprm-recipe-container">
            <div class="wprm-recipe-ingredient-group">
              <h4 class="wprm-recipe-ingredient-group-header">
                Not an ingredient
              </h4>
            </div>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // The class is a substring but not the token, so the group name
        // is not collected.
        #expect(card.ingredients.isEmpty)
    }

    // MARK: - Deep nesting

    /// A recipe container with many levels of nested `<div>` before reaching
    /// the ingredient rows. This stress-tests depth-tracking in
    /// `sliceUntilMatchingClose`.
    @Test func handlsDeeplyNestedDivsInsideContainer() {
        let html = """
            <div class="wprm-recipe-container">
            <div><div><div><div><div>
              <ul class="wprm-recipe-ingredients">
              <li class="wprm-recipe-ingredient">
                <span class="wprm-recipe-ingredient-name">deeply nested</span>
              </li>
              </ul>
            </div></div></div></div></div>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["deeply nested"])
    }

    // MARK: - Self-closing and void tags

    /// An ingredient row containing self-closing void tags (`<br/>`, `<img/>`)
    /// that have no matching close. The parser should ignore them (they don't
    /// open a nesting level) and extract the text around them.
    @Test func extractsTextAroundSelfClosingVoidTags() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-amount">2</span>
              <br/>
              <span class="wprm-recipe-ingredient-unit">cups</span>
              <img src="icon.png" />
              <span class="wprm-recipe-ingredient-name">flour</span>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // The void tags are ignored; text is extracted.
        #expect(card.ingredients == ["2 cups flour"])
    }

    // MARK: - Mixed-case tags

    /// Tags with mixed case (e.g., `<Li>`, `<DIV>`, `</LI>`) should match
    /// because `sliceRecipeContainer` and `collectElementTexts` use
    /// case-insensitive search.
    @Test func parsesMixedCaseTags() {
        let html = """
            <DIV class="wprm-recipe-container">
            <UL class="wprm-recipe-ingredients">
            <LI class="wprm-recipe-ingredient">
              <SPAN class="wprm-recipe-ingredient-name">salt</SPAN>
            </LI>
            </UL>
            </DIV>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["salt"])
    }

    // MARK: - Unclosed tags

    /// An ingredient row that never closes (no `</li>`). The parser uses
    /// depth-tracking in `sliceUntilMatchingClose`, which looks for the
    /// matching close. If it never finds one, slicing fails and that row
    /// is skipped.
    @Test func skipsUnclosedIngredientRowTags() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-name">unclosed row
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-name">next row</span>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // The first row is never closed, so slicing fails and it's skipped.
        // The second row should be extracted.
        #expect(card.ingredients.contains("next row"))
    }

    /// A recipe container that never closes. The depth-tracking will fail
    /// to find the matching close, and `sliceRecipeContainer` returns nil.
    @Test func returnsEmptyWhenContainerNeverCloses() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-name">orphaned</span>
            </li>
            </ul>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // No closing </div> for the container, so slicing fails.
        #expect(card.ingredients.isEmpty)
        #expect(card.instructions.isEmpty)
    }

    // MARK: - Instruction row edge cases

    /// An instruction row without the inner `wprm-recipe-instruction-text`
    /// wrapper. The parser falls back to plain-texting the entire row.
    @Test func instructionRowWithoutTextWrapperUsesWholeRow() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-instructions">
            <li class="wprm-recipe-instruction">
              Heat the oven to 350°F.
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.instructions == ["Heat the oven to 350°F."])
    }

    /// An instruction row with empty inner text wrapper.
    @Test func instructionRowWithEmptyTextWrapperReturnsEmpty() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-instructions">
            <li class="wprm-recipe-instruction">
              <div class="wprm-recipe-instruction-text"></div>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // Empty text wrapper results in empty plain text, which is filtered out.
        #expect(card.instructions.isEmpty)
    }

    // MARK: - Comment edge cases

    /// A comment inside an ingredient row that contains tag-like text.
    /// Comments are stripped before parsing, so the comment content is removed.
    @Test func commentInsideIngredientRowIsStripped() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-amount">1</span>
              <!-- old markup: <span> teaspoon </span> -->
              <span class="wprm-recipe-ingredient-name">salt</span>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredients == ["1 salt"])
    }

    /// A comment containing tag-like text but unclosed (missing `-->`).
    /// The HTML sanitizer drops everything after an unterminated comment,
    /// which includes the closing tags. The parser should not crash even
    /// when the container never closes as a result.
    @Test func unclosedCommentDropsRemainingHtml() {
        let html = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-name">salt</span>
              <!-- stray comment without close
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // The unclosed comment causes the sanitizer to drop everything after it,
        // including the closing `</div>`. So sliceRecipeContainer fails to find
        // the matching close and returns nil → empty ingredients.
        #expect(card.ingredients.isEmpty)
    }

    // MARK: - Attribute edge cases

    /// Multiple `class=` attributes in a single tag (malformed HTML).
    /// The `hasClassToken` function finds the first `class=` it encounters,
    /// so only the first is checked. This is a degraded case.
    @Test func multipleClassAttributesChecksFirstOnly() {
        let html = """
            <div class="wprm-recipe-container" class="extra-class">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-name">salt</span>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // Malformed but the first class attribute contains the token, so
        // the container is detected.
        #expect(card.ingredients == ["salt"])
    }

    /// An unquoted class attribute (malformed but sometimes seen).
    /// `hasClassToken` handles unquoted attributes by splitting on whitespace
    /// and comparing the first token.
    @Test func unquotedClassAttributeHandled() {
        let html = """
            <div class=wprm-recipe-container>
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-name">salt</span>
            </li>
            </ul>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        // Unquoted attribute with exact token match.
        #expect(card.ingredients == ["salt"])
    }
}

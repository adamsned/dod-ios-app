import Testing

@testable import DODSupport

@Suite("HTMLSanitizer.plainText") struct HTMLSanitizerTests {

    @Test func stripsSimpleParagraphTags() {
        let result = HTMLSanitizer.plainText(from: "<p>Hello world.</p>")
        #expect(result == "Hello world.")
    }

    @Test func stripsNestedTags() {
        let result = HTMLSanitizer.plainText(from: "<p>Hello <strong>world</strong>.</p>")
        #expect(result == "Hello world.")
    }

    @Test func decodesNamedEntities() {
        let result = HTMLSanitizer.plainText(from: "Sweet &amp; salty &mdash; perfect.")
        #expect(result == "Sweet & salty — perfect.")
    }

    @Test func decodesDecimalNumericEntities() {
        let result = HTMLSanitizer.plainText(from: "It&#8217;s great!")
        #expect(result == "It\u{2019}s great!")
    }

    @Test func decodesHexNumericEntities() {
        let result = HTMLSanitizer.plainText(from: "snowman &#x2603;")
        #expect(result == "snowman ☃")
    }

    // DUT-550: WordPress/WPRM emits the NAMED form of common recipe entities
    // (`&frac12;` in "1½ cups", `&deg;` in oven temps). These must decode to
    // their glyphs, not pass through raw into the ingredient-amount field.
    @Test func decodesNamedVulgarFractionEntities() {
        let result = HTMLSanitizer.plainText(from: "1&frac12; cups flour, &frac14; cup sugar, &frac34; tsp salt")
        #expect(result == "1½ cups flour, ¼ cup sugar, ¾ tsp salt")
    }

    @Test func decodesThirdsAndEighthsFractionEntities() {
        let result = HTMLSanitizer.plainText(from: "&frac13; &frac23; &frac18; &frac38; &frac58; &frac78;")
        #expect(result == "⅓ ⅔ ⅛ ⅜ ⅝ ⅞")
    }

    @Test func decodesDegreeAndMathEntities() {
        let result = HTMLSanitizer.plainText(from: "Bake at 350&deg;F. Use a 9&times;13 pan. Serves 4&divide;2.")
        #expect(result == "Bake at 350°F. Use a 9×13 pan. Serves 4÷2.")
    }

    @Test func collapsesWhitespace() {
        let result = HTMLSanitizer.plainText(from: "  one    two\n\nthree  ")
        #expect(result == "one two three")
    }

    @Test func emptyInputReturnsEmpty() {
        #expect(HTMLSanitizer.plainText(from: "").isEmpty)
    }

    @Test func handlesMultibyteCharacters() {
        let result = HTMLSanitizer.plainText(from: "<p>Café — 日本語</p>")
        #expect(result == "Café — 日本語")
    }

    @Test func unknownEntitiesArePreserved() {
        // Anything we can't decode should pass through verbatim, not get eaten.
        let result = HTMLSanitizer.plainText(from: "Read &foobar; about it")
        #expect(result == "Read &foobar; about it")
    }

    // MARK: - DUT-466: double-encoded entities (mirrors DUT-394)

    @Test func decodesDoubleEncodedNumericEntity() {
        // WP REST bodies routinely double-encode: `&amp;#8217;` must resolve all
        // the way to the apostrophe, not stop at the raw `&#8217;`.
        let result = HTMLSanitizer.plainText(from: "It&amp;#8217;s great!")
        #expect(result == "It\u{2019}s great!")
    }

    @Test func decodesDoubleEncodedAmpersand() {
        let result = HTMLSanitizer.plainText(from: "Salt &amp;amp; pepper")
        #expect(result == "Salt & pepper")
    }

    @Test func singleEncodedAmpersandStillDecodesToOne() {
        // The second pass must NOT over-decode a genuine single `&amp;`.
        let result = HTMLSanitizer.plainText(from: "Sweet &amp; salty")
        #expect(result == "Sweet & salty")
    }

    // MARK: - DUT-389: comment stripping

    @Test func stripsSimpleHTMLComment() {
        let result = HTMLSanitizer.plainText(from: "<p>Before<!-- hidden -->After</p>")
        #expect(result == "BeforeAfter")
    }

    @Test func commentWithInnerAngleBracketDoesNotLeak() {
        // The inner `>` must NOT terminate the comment early and leak "b -->".
        let result = HTMLSanitizer.plainText(from: "<p>x<!-- a > b -->y</p>")
        #expect(result == "xy")
    }

    @Test func commentWithInnerDivDoesNotLeak() {
        let result = HTMLSanitizer.plainText(from: "A<!-- <div id=ad> --><p>B</p>")
        #expect(result == "AB")
    }

    @Test func unterminatedCommentDropsToEnd() {
        // Mirrors the unterminated-<script> policy: drop the remainder.
        let result = HTMLSanitizer.plainText(from: "Keep<!-- never closes and runs on")
        #expect(result == "Keep")
    }

    @Test func strippingCommentsLeavesNonCommentInputUntouched() {
        #expect(HTMLSanitizer.strippingComments("<p>no comments here</p>") == "<p>no comments here</p>")
    }

    // MARK: - DUT-437: script/style bodies are opaque to the comment strip

    @Test func commentOpenInsideScriptDoesNotEatFollowingProse() {
        // `a<!--b` is valid JS; the un-closed "comment" must NOT swallow the
        // script close or the paragraph after it.
        let html = #"<script>var x = a<!--b;</script><p>Keep me</p>"#
        let stripped = HTMLSanitizer.strippingComments(html)
        #expect(stripped.contains("<p>Keep me</p>"))
        #expect(stripped.contains("</script>"))
    }

    @Test func realCommentAfterScriptStillStripped() {
        let html = #"<script>var s = "<!--";</script><!-- gone --><p>Body</p>"#
        let stripped = HTMLSanitizer.strippingComments(html)
        #expect(!stripped.contains("gone"))
        #expect(stripped.contains("<p>Body</p>"))
        #expect(stripped.contains("</script>"))
    }

    @Test func commentBeforeScriptStillStripped() {
        let html = "<!-- top --><script>1</script><p>Body</p>"
        let stripped = HTMLSanitizer.strippingComments(html)
        #expect(!stripped.contains("top"))
        #expect(stripped.contains("<script>1</script>"))
    }
}

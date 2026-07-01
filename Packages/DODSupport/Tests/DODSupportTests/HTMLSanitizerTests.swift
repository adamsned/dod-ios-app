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
}

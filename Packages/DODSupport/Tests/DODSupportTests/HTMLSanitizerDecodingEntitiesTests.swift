import Testing

@testable import DODSupport

@Suite("HTMLSanitizer.decodingEntities") struct HTMLSanitizerDecodingEntitiesTests {

    // MARK: - Basic Named Entity Decoding

    @Test func decodesSimpleAmpersandEntity() {
        let result = HTMLSanitizer.decodingEntities("Salt &amp; Pepper")
        #expect(result == "Salt & Pepper")
    }

    @Test func decodesMultipleNamedEntitiesInSequence() {
        let result = HTMLSanitizer.decodingEntities("&lt;tag&gt; &quot;quoted&quot;")
        #expect(result == "<tag> \"quoted\"")
    }

    @Test func decodesApostropheEntity() {
        let result = HTMLSanitizer.decodingEntities("It&apos;s working")
        #expect(result == "It's working")
    }

    @Test func decodesEllipsisEntity() {
        let result = HTMLSanitizer.decodingEntities("Wait&hellip; more text")
        #expect(result == "Wait… more text")
    }

    // MARK: - Numeric Entity Decoding

    @Test func decodesDecimalNumericEntity() {
        let result = HTMLSanitizer.decodingEntities("&#233;clair")
        #expect(result == "éclair")
    }

    @Test func decodesHexNumericEntity() {
        let result = HTMLSanitizer.decodingEntities("&#xE9;clair")
        #expect(result == "éclair")
    }

    @Test func decodesCapitalXHexNumericEntity() {
        let result = HTMLSanitizer.decodingEntities("snowman &#X2603;")
        #expect(result == "snowman ☃")
    }

    // MARK: - Non-Breaking Space Entity

    @Test func decodesNonBreakingSpaceToRegularSpace() {
        // &nbsp; in the source maps to " " (U+0020, regular space), not U+00A0 (non-breaking space)
        let result = HTMLSanitizer.decodingEntities("a&nbsp;b")
        #expect(result == "a b")
    }

    // MARK: - Key Distinguishing Behavior: Tags NOT Stripped

    @Test func preservesHTMLTagsInInput() {
        // This is the CRITICAL distinction from plainText(from:), which strips tags.
        // decodingEntities must leave tags untouched while decoding entities.
        let result = HTMLSanitizer.decodingEntities("<b>Bold &amp; Italic</b>")
        #expect(result == "<b>Bold & Italic</b>")
    }

    @Test func preservesNestedHTMLTags() {
        let result = HTMLSanitizer.decodingEntities("<div><span>Text &amp; more</span></div>")
        #expect(result == "<div><span>Text & more</span></div>")
    }

    @Test func preservesSelfClosingTags() {
        let result = HTMLSanitizer.decodingEntities("Image &amp; <br/> break")
        #expect(result == "Image & <br/> break")
    }

    // MARK: - Key Distinguishing Behavior: Whitespace NOT Collapsed

    @Test func preservesMultipleConsecutiveSpaces() {
        // This is the CRITICAL distinction from plainText(from:), which collapses whitespace.
        // decodingEntities must preserve internal whitespace while only decoding entities.
        let result = HTMLSanitizer.decodingEntities("multiple   spaces  &amp;  more")
        #expect(result == "multiple   spaces  &  more")
    }

    @Test func preservesNewlinesAndTabs() {
        let result = HTMLSanitizer.decodingEntities("line1\nline2\tand &amp; more")
        #expect(result == "line1\nline2\tand & more")
    }

    @Test func preservesLeadingAndTrailingWhitespace() {
        let result = HTMLSanitizer.decodingEntities("  text &amp; more  ")
        #expect(result == "  text & more  ")
    }

    // MARK: - No Entities Present (Pass-Through)

    @Test func passesPlainTextUnchanged() {
        let result = HTMLSanitizer.decodingEntities("plain text, no entities")
        #expect(result == "plain text, no entities")
    }

    @Test func passesHTMLTagsWithoutEntitiesUnchanged() {
        let result = HTMLSanitizer.decodingEntities("<p>Simple paragraph</p>")
        #expect(result == "<p>Simple paragraph</p>")
    }

    // MARK: - Edge Cases

    @Test func emptyStringReturnsEmpty() {
        let result = HTMLSanitizer.decodingEntities("")
        #expect(result.isEmpty)
    }

    @Test func preservesUnknownEntities() {
        // Unknown/unrecognized entities pass through verbatim
        let result = HTMLSanitizer.decodingEntities("Read &foobar; about it")
        #expect(result == "Read &foobar; about it")
    }

    @Test func handlesLiteralAmpersandWithoutSemicolon() {
        // An ampersand not followed by a semicolon passes through
        let result = HTMLSanitizer.decodingEntities("A & B without entity syntax")
        #expect(result == "A & B without entity syntax")
    }

    // MARK: - Double-Encoding (Two-Pass Decoding)

    @Test func decodesDoubleEncodedNumericEntity() {
        // WP REST bodies routinely double-encode: `&amp;#233;` → `&#233;` → `é`
        let result = HTMLSanitizer.decodingEntities("caf&amp;#233;")
        #expect(result == "café")
    }

    @Test func decodesDoubleEncodedNamedEntity() {
        let result = HTMLSanitizer.decodingEntities("Salt &amp;amp; Pepper")
        #expect(result == "Salt & Pepper")
    }

    @Test func singleEncodedAmpersandIsNotOverDecoded() {
        // A genuine single &amp; must decode to &, not further
        let result = HTMLSanitizer.decodingEntities("Sweet &amp; salty")
        #expect(result == "Sweet & salty")
    }

    // MARK: - Complex Combinations

    @Test func decodesMultipleEntitiesWithPreservedTags() {
        let result = HTMLSanitizer.decodingEntities(
            "<p>A &lt;recipe&gt; for &quot;Saut&eacute;ed&quot; vegetables &amp; herbs</p>"
        )
        #expect(result == "<p>A <recipe> for \"Sautéed\" vegetables & herbs</p>")
    }

    @Test func decodesEntitiesWithPreservedComplexWhitespace() {
        let result = HTMLSanitizer.decodingEntities(
            "  Line 1  \n  &lt;tag&gt;  &amp;  entities  \n  Line 3  "
        )
        #expect(result == "  Line 1  \n  <tag>  &  entities  \n  Line 3  ")
    }

    @Test func decodesAccentedEntityInTagAttribute() {
        // Attribute values often contain entities that must be decoded while preserving tag structure
        let result = HTMLSanitizer.decodingEntities("<div title=\"Caf&eacute;\">Menu</div>")
        #expect(result == "<div title=\"Café\">Menu</div>")
    }
}

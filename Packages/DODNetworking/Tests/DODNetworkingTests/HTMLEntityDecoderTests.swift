import Foundation
import Testing

@testable import DODNetworking

/// DUT-27: WordPress REST messages and comment bodies arrive with HTML
/// entities (the build-8 duplicate report showed "you&#8217;ve already said
/// that"). These pin the dependency-free decoder so the displayed text reads
/// as real punctuation, never the raw entity.
@Suite("HTMLEntityDecoder (DUT-27)")
struct HTMLEntityDecoderTests {

    // MARK: - Numeric entities

    /// The exact entity from the build-8 duplicate message: `&#8217;` is the
    /// right single quotation mark WordPress substitutes for a typed
    /// apostrophe. We render it as a plain ASCII apostrophe-equivalent glyph.
    @Test func decimalRightSingleQuoteResolvesToApostropheGlyph() {
        #expect(HTMLEntityDecoder.decode("you&#8217;ve") == "you\u{2019}ve")
    }

    /// The whole build-8 duplicate string decodes so no raw entity leaks into
    /// the snackbar. "you&#8217;ve" → "you’ve" (curly apostrophe).
    @Test func buildEightDuplicateMessageDecodesToReadableText() {
        let raw = "Duplicate comment detected; it looks as though you&#8217;ve already said that!"
        let expected = "Duplicate comment detected; it looks as though you\u{2019}ve already said that!"
        #expect(HTMLEntityDecoder.decode(raw) == expected)
    }

    /// Hex numeric references resolve via the same Unicode scalar path —
    /// `&#x2019;` is the hex spelling of `&#8217;`.
    @Test func hexNumericReferenceResolves() {
        #expect(HTMLEntityDecoder.decode("you&#x2019;ve") == "you\u{2019}ve")
        // Upper-case X marker is accepted too.
        #expect(HTMLEntityDecoder.decode("A&#X2019;B") == "A\u{2019}B")
    }

    /// Leading-zero decimal (`&#039;`) decodes to a straight apostrophe.
    @Test func zeroPaddedDecimalApostropheResolves() {
        #expect(HTMLEntityDecoder.decode("it&#039;s") == "it's")
    }

    /// An emoji code point round-trips, proving scalars above the BMP work.
    @Test func astralCodePointResolves() {
        #expect(HTMLEntityDecoder.decode("fire &#128293;") == "fire \u{1F525}")
    }

    /// A malformed / out-of-range reference is left verbatim rather than
    /// dropped, so a stray token never silently eats surrounding text.
    @Test func invalidNumericReferenceIsLeftVerbatim() {
        // 0x11FFFF is beyond the Unicode range → not a valid scalar.
        #expect(HTMLEntityDecoder.decode("x&#x11FFFF;y") == "x&#x11FFFF;y")
    }

    // MARK: - Named entities

    @Test func commonNamedEntitiesDecode() {
        #expect(HTMLEntityDecoder.decode("a &lt; b &gt; c") == "a < b > c")
        #expect(HTMLEntityDecoder.decode("she said &quot;hi&quot;") == "she said \"hi\"")
        #expect(HTMLEntityDecoder.decode("it&#39;s &apos;quoted&apos;") == "it's 'quoted'")
        #expect(HTMLEntityDecoder.decode("Salt&nbsp;&amp;&nbsp;pepper") == "Salt\u{00A0}&\u{00A0}pepper")
        #expect(HTMLEntityDecoder.decode("More&hellip;") == "More\u{2026}")
    }

    /// `&amp;` collapses to a single `&` and is decoded last, so an
    /// already-escaped `&amp;#8217;` first becomes `&#8217;` (the literal
    /// text), not a decoded curly quote — we do not double-decode.
    @Test func ampersandDecodesLastAndDoesNotDoubleDecode() {
        #expect(HTMLEntityDecoder.decode("Tom &amp; Jerry") == "Tom & Jerry")
        #expect(HTMLEntityDecoder.decode("&amp;#8217;") == "&#8217;")
    }

    // MARK: - Pass-through

    /// Strings with no `&` short-circuit unchanged (the fast path).
    @Test func stringWithoutAmpersandIsUnchanged() {
        #expect(HTMLEntityDecoder.decode("plain text, no entities") == "plain text, no entities")
    }

    @Test func emptyStringIsUnchanged() {
        #expect(HTMLEntityDecoder.decode("").isEmpty)
    }

    // MARK: - stripHTML integration (the path the error message flows through)

    /// `WPCommentsClient.stripHTML` drops tags AND decodes entities, so the
    /// `httpStatusWithBody` message a 409 carries is already clean by the time
    /// the view layer reads it (DUT-27).
    @Test func stripHTMLDropsTagsThenDecodesEntities() {
        let raw = "<p>it looks as though you&#8217;ve already said that!</p>"
        let cleaned = WPCommentsClient.stripHTML(raw)
        #expect(!cleaned.contains("<"))
        #expect(!cleaned.contains("&#"))
        #expect(cleaned == "it looks as though you\u{2019}ve already said that!")
    }
}

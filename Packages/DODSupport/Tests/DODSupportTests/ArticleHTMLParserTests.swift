import Foundation
import Testing

@testable import DODSupport

/// L1 unit tests for ``ArticleHTMLParser``.
///
/// Spec trace: DOD-ART-1. The parser walks the sanitized `entry-content` of a
/// WordPress post and emits ``ArticleBlock`` values in document order, with
/// inline bold / italic / link runs preserved as ``AttributedString``
/// attributes. Fixtures mirror the live round-up markup (post 23406): Gutenberg
/// `wp-block-*` classes, attributes in any order, irregular whitespace, and
/// entities like `&#9989;` (✅) / `&nbsp;` / `&amp;`.
@Suite("ArticleHTMLParser.parse") struct ArticleHTMLParserTests {

    // MARK: - Helpers

    /// The plain-text characters of an ``AttributedString``.
    private func text(_ value: AttributedString) -> String { String(value.characters) }

    /// Whether any run of `value` carries every intent in `intents`.
    private func hasRun(
        _ value: AttributedString,
        withIntent intents: InlinePresentationIntent
    ) -> Bool {
        value.runs.contains { ($0.inlinePresentationIntent ?? []).contains(intents) }
    }

    // MARK: - Headings

    @Test func parsesHeadingLevels() {
        let blocks = ArticleHTMLParser.parse(
            html: """
                <h2 id="quick-look-at-this-roundup"   class="wp-block-heading" >Quick Look at this Roundup</h2>
                <h3 class="wp-block-heading" id="ingredients">Ingredients You'll Need</h3>
                """
        )
        #expect(blocks.count == 2)
        #expect(blocks[0] == .heading(level: 2, text: AttributedString("Quick Look at this Roundup")))
        #expect(blocks[1] == .heading(level: 3, text: AttributedString("Ingredients You'll Need")))
    }

    @Test func clampsHeadingLevelRange() {
        // h1..h6 are recognized and pass through clamped to 1...6.
        let blocks = ArticleHTMLParser.parse(html: "<h1>Top</h1><h6>Bottom</h6>")
        #expect(blocks.count == 2)
        if case .heading(let level, _) = blocks[0] { #expect(level == 1) } else { Issue.record("not heading") }
        if case .heading(let level, _) = blocks[1] { #expect(level == 6) } else { Issue.record("not heading") }
    }

    // MARK: - Paragraphs (inline runs)

    @Test func parsesParagraphWithBoldItalicAndLinkRuns() {
        let html = """
            <p>These are the <strong>best dutch oven recipes</strong> I have \
            <em>tested dozens of times</em> — see <a href="https://www.dutchovendaddy.com/chili/">my chili</a>.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        guard case .paragraph(let attributed) = blocks[0] else {
            Issue.record("expected a paragraph")
            return
        }
        // Plain text round-trips with entities + inline tags removed.
        #expect(text(attributed).contains("best dutch oven recipes"))
        #expect(text(attributed).contains("tested dozens of times"))

        // Bold run.
        #expect(hasRun(attributed, withIntent: .stronglyEmphasized))
        // Italic run.
        #expect(hasRun(attributed, withIntent: .emphasized))

        // Link run carries the href as a URL.
        let linkRun = attributed.runs.first { $0.link != nil }
        #expect(linkRun?.link == URL(string: "https://www.dutchovendaddy.com/chili/"))
        // The bold span itself is not a link.
        let boldRun = attributed.runs.first { ($0.inlinePresentationIntent ?? []).contains(.stronglyEmphasized) }
        #expect(boldRun?.link == nil)
    }

    @Test func parsesNestedBoldItalicAsCombinedIntent() {
        let html = "<p>plain <strong>bold <em>both</em></strong> tail</p>"
        let blocks = ArticleHTMLParser.parse(html: html)
        guard case .paragraph(let attributed) = blocks.first else {
            Issue.record("expected a paragraph")
            return
        }
        // The "both" run carries strong AND emphasized together.
        let combined = attributed.runs.first { run in
            let intent = run.inlinePresentationIntent ?? []
            return intent.contains(.stronglyEmphasized) && intent.contains(.emphasized)
        }
        #expect(combined != nil)
    }

    @Test func rendersBlockquoteAsParagraph() {
        let blocks = ArticleHTMLParser.parse(html: "<blockquote><p>A wise quote.</p></blockquote>")
        #expect(blocks == [.paragraph(AttributedString("A wise quote."))])
    }

    // MARK: - Images

    @Test func parsesFigureWithImageAndFigcaption() throws {
        let html = """
            <figure class="wp-block-image size-full">\
            <img decoding="async" width="1200" height="1600" \
            src="https://www.dutchovendaddy.com/wp-content/uploads/2026/05/best_dutch_oven_recipes.jpg" \
            alt="The Best Dutch Oven Recipes. " \
            srcset="https://www.dutchovendaddy.com/wp-content/uploads/2026/05/should-not-be-used.jpg 1200w" \
            class="wp-image-23423">\
            <figcaption class="wp-element-caption">A hearty spread.</figcaption></figure>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        let expectedURL = try #require(
            URL(string: "https://www.dutchovendaddy.com/wp-content/uploads/2026/05/best_dutch_oven_recipes.jpg")
        )
        #expect(blocks.first == .image(url: expectedURL, caption: "A hearty spread."))
    }

    @Test func figureFallsBackToAltWhenNoFigcaption() throws {
        let html = """
            <figure class="wp-block-image"><img src="https://example.com/a.jpg" alt="The Best Dutch Oven Recipes. ">\
            </figure>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        // alt is used as caption; src is taken from src= (never srcset).
        let url = try #require(URL(string: "https://example.com/a.jpg"))
        #expect(blocks == [.image(url: url, caption: "The Best Dutch Oven Recipes.")])
    }

    @Test func parsesStandaloneImage() throws {
        let blocks = ArticleHTMLParser.parse(html: "<img src=\"https://example.com/solo.png\" alt=\"Solo\">")
        let url = try #require(URL(string: "https://example.com/solo.png"))
        #expect(blocks == [.image(url: url, caption: "Solo")])
    }

    @Test func standaloneImageWithoutAltHasNilCaption() throws {
        let blocks = ArticleHTMLParser.parse(html: "<img src=\"https://example.com/x.png\">")
        let url = try #require(URL(string: "https://example.com/x.png"))
        #expect(blocks == [.image(url: url, caption: nil)])
    }

    @Test func skipsImageWithMissingOrInvalidSource() {
        // No src at all.
        #expect(ArticleHTMLParser.parse(html: "<img alt=\"no source\">").isEmpty)
        // Empty src.
        #expect(ArticleHTMLParser.parse(html: "<figure><img src=\"\" alt=\"x\"></figure>").isEmpty)
        // src that URL(string:) rejects outright (malformed authority).
        #expect(URL(string: "http://[bad") == nil)
        #expect(ArticleHTMLParser.parse(html: "<img src=\"http://[bad\">").isEmpty)
    }

    // MARK: - Lists

    @Test func parsesUnorderedListWithDecodedEntities() {
        let html = """
            <ul class="wp-block-list"><li>&#9989;&nbsp;<strong>Total Recipes:</strong>&nbsp;30+</li>\
            <li>Salt &amp; pepper</li></ul>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        guard case .list(let ordered, let items) = blocks[0] else {
            Issue.record("expected a list")
            return
        }
        #expect(ordered == false)
        #expect(items.count == 2)
        // ✅ decodes, &nbsp; → space, &amp; → &.
        #expect(text(items[0]).contains("✅"))
        #expect(text(items[0]).contains("Total Recipes:"))
        #expect(text(items[0]).contains("30+"))
        #expect(text(items[1]) == "Salt & pepper")
        // The first item's "Total Recipes:" span is bold.
        #expect(hasRun(items[0], withIntent: .stronglyEmphasized))
    }

    @Test func parsesOrderedList() {
        let blocks = ArticleHTMLParser.parse(html: "<ol><li>First</li><li>Second</li><li>Third</li></ol>")
        #expect(
            blocks == [
                .list(
                    ordered: true,
                    items: [AttributedString("First"), AttributedString("Second"), AttributedString("Third")]
                )
            ]
        )
    }

    // MARK: - Document order

    @Test func preservesDocumentOrderAcrossMultiBlockFixture() {
        let blocks = ArticleHTMLParser.parse(html: Self.roundupFixture)
        // figure, h2, h3, p, ul — in that order.
        #expect(blocks.count == 5)
        guard case .image = blocks[0] else {
            Issue.record("block 0 should be the figure image")
            return
        }
        #expect(blocks[1] == .heading(level: 2, text: AttributedString("Quick Look at this Roundup")))
        #expect(blocks[2] == .heading(level: 3, text: AttributedString("Best Overall Pick")))
        guard case .paragraph = blocks[3] else {
            Issue.record("block 3 should be the paragraph")
            return
        }
        guard case .list(let ordered, let items) = blocks[4] else {
            Issue.record("block 4 should be the list")
            return
        }
        #expect(ordered == false)
        #expect(items.count == 2)
    }

    @Test func scopesToEntryContentWrapper() {
        // Chrome outside entry-content (and a nav heading) must be ignored.
        let html = """
            <html><body><header><h1>Site Nav</h1></header>
            <div class="entry-content"><p>Real body.</p></div>
            <footer><p>Footer junk.</p></footer></body></html>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks == [.paragraph(AttributedString("Real body."))])
    }

    // MARK: - Robustness

    @Test func skipsWhitespaceOnlyParagraph() {
        let blocks = ArticleHTMLParser.parse(html: "<p>   &nbsp; \n </p><p>Kept.</p>")
        #expect(blocks == [.paragraph(AttributedString("Kept."))])
    }

    @Test func removesScriptAndStyleContent() {
        let html = """
            <p>Before.</p>
            <script>var x = "<p>injected</p>"; alert(1);</script>
            <style>.foo { color: red; } p::before { content: "noise"; }</style>
            <p>After.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks == [.paragraph(AttributedString("Before.")), .paragraph(AttributedString("After."))])
        // The injected paragraph text inside <script> must not leak through.
        let joined = blocks.map { block -> String in
            if case .paragraph(let value) = block { return String(value.characters) }
            return ""
        }
        .joined(separator: "|")
        #expect(!joined.contains("injected"))
        #expect(!joined.contains("noise"))
    }

    @Test func removesNoscriptAndSvgContent() {
        let html = """
            <p>Alpha.</p>
            <noscript><p>enable js</p></noscript>
            <svg><text>vector text</text></svg>
            <p>Beta.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks == [.paragraph(AttributedString("Alpha.")), .paragraph(AttributedString("Beta."))])
    }

    @Test func emptyInputReturnsNoBlocks() {
        #expect(ArticleHTMLParser.parse(html: "").isEmpty)
    }

    // MARK: - Malformed input / robustness (review DOD-ART-1)

    /// Regression for the inline-scanner hang: a stray `<` with no following
    /// `>` in prose ("Cook for <5 min") must render as a literal character.
    /// Before the fix the cursor never advanced past the lone `<`, looping
    /// forever and freezing the article screen — so if this regresses the
    /// suite HANGS (times out), which is the intended guard.
    @Test func strayLessThanInProseRendersLiterallyWithoutHanging() {
        let blocks = ArticleHTMLParser.parse(
            html: #"<div class="entry-content"><p>Cook for <5 min, then serve.</p></div>"#
        )
        #expect(blocks.count == 1)
        guard case .paragraph(let body) = blocks.first else {
            Issue.record("expected one paragraph, got \(blocks)")
            return
        }
        #expect(text(body) == "Cook for <5 min, then serve.")
    }

    /// A `<` at the very end of a block's inner content (no following `>`)
    /// also terminates rather than hanging.
    @Test func trailingBareLessThanTerminates() {
        let blocks = ArticleHTMLParser.parse(html: "<p>Serve hot <</p>")
        #expect(blocks.count == 1)
        guard case .paragraph(let body) = blocks.first else {
            Issue.record("expected one paragraph, got \(blocks)")
            return
        }
        #expect(text(body) == "Serve hot <")
    }

    // DUT-437 comment-vs-slice-boundary regression tests live in
    // `ArticleHTMLParserCommentBoundaryTests.swift` (type_body_length cap).

    // MARK: - Fixture

    /// A focused multi-block fixture mirroring the live round-up (post 23406):
    /// a hero `<figure>`, two Gutenberg headings, an intro paragraph with
    /// inline emphasis + a recipe link, and a `wp-block-list` whose first item
    /// carries `&#9989;` / `&nbsp;` entities. Attribute order and whitespace are
    /// deliberately irregular.
    static let roundupFixture = """
        <figure class="wp-block-image size-full"><img decoding="async" width="1200" height="1600" \
        src="https://www.dutchovendaddy.com/wp-content/uploads/2026/05/best_dutch_oven_recipes.jpg" \
        alt="The Best Dutch Oven Recipes. " srcset="https://www.dutchovendaddy.com/ignore.jpg 1200w" \
        class="wp-image-23423"></figure>
        <h2 id="quick-look-at-this-roundup"   class="wp-block-heading" >Quick Look at this Roundup</h2>
        <h3 class="wp-block-heading" id="best-overall-pick">Best Overall Pick</h3>
        <p>These are the <strong>best dutch oven recipes</strong> — all <em>tested dozens of times</em> — \
        starting with <a href="https://www.dutchovendaddy.com/dutch-oven-chili/">our chili</a>.</p>
        <ul class="wp-block-list"><li>&#9989;&nbsp;<strong>Total Recipes:</strong>&nbsp;30+</li>\
        <li>&#9989;&nbsp;<strong>Skill Level:</strong>&nbsp;Easy &amp; up</li></ul>
        """
}

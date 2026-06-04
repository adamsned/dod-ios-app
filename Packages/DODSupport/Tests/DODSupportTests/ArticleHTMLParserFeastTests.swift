import Foundation
import Testing

@testable import DODSupport

/// L1 regression tests for the Feast-theme "SEO action button" stripping
/// (DUT-21). The Feast plugin injects a "Summarize and Save the Recipe" cluster
/// — an AI-prompt launcher (`feast-ai-buttons-block`: ChatGPT / Google AI /
/// Perplexity / Grok) and a `feast-trusted-google-source` button — into every
/// post body. In the native article render the buttons are non-functional and
/// the heading renders as an orphan, so ``ArticleHTMLParser`` drops the whole
/// cluster at parse time. The recipe / category index grids and jump-to
/// navigation Feast blocks in a round-up body are REAL content and must survive.
@Suite("ArticleHTMLParser.parse Feast stripping (DUT-21)") struct ArticleHTMLParserFeastTests {

    /// The plain-text characters of an ``AttributedString``.
    private func text(_ value: AttributedString) -> String { String(value.characters) }

    /// Every link URL carried by the runs of all paragraph blocks.
    private func paragraphLinks(_ blocks: [ArticleBlock]) -> [URL] {
        blocks.flatMap { block -> [URL] in
            guard case .paragraph(let value) = block else { return [] }
            return value.runs.compactMap(\.link)
        }
    }

    // MARK: - Golden fixture (live capture, /dump-cake-recipes/, 2026-06)

    /// Mirrors the live Feast cluster: a `wp-block-group` holding the
    /// `h-summarize-and-save-the-recipe` heading, the `feast-ai-buttons-block`
    /// (four AI buttons), and the adjacent `feast-trusted-google-source` button
    /// (with an inline `<svg>` icon), bracketed by real prose with recipe links
    /// the parser must keep. Buttons nest `wp-block-buttons` / `wp-block-button`
    /// so the strip must depth-balance the `<div>`s.
    static let feastBlockFixture = """
        <div class="entry-content">
        <p>Intro prose with a <a href="https://www.dutchovendaddy.com/dutch-oven-chili/">chili link</a>.</p>
        <div class="wp-block-group"><div class="wp-block-group__inner-container">
        <h3 class="wp-block-heading" id="h-summarize-and-save-the-recipe">Summarize and Save the Recipe</h3>
        <div class="feast-ai-buttons-block feast-ai-buttons-block--align-center"><div class="wp-block-buttons">\
        <div class="wp-block-button"><a href="https://chatgpt.com/?q=x">ChatGPT</a></div>\
        <div class="wp-block-button"><a href="https://www.google.com/search?udm=50&amp;q=x">Google AI</a></div>\
        <div class="wp-block-button"><a href="https://www.perplexity.ai/search?q=x">Perplexity</a></div>\
        <div class="wp-block-button"><a href="https://x.com/i/grok?text=x">Grok</a></div>\
        </div></div>
        <div class="feast-trusted-google-source"><div class="wp-block-buttons"><div class="wp-block-button">\
        <a href="https://www.google.com/preferences/source?q=x"><svg viewbox="0 0 640 640"><path d="M1Z"/></svg>\
        Trusted Source</a></div></div></div>
        </div></div>
        <p>Closing prose with <a href="https://www.dutchovendaddy.com/peach-cobbler/">peach cobbler</a>.</p>
        </div>
        """

    @Test func stripsFeastSummarizeAndSaveCluster() {
        let blocks = ArticleHTMLParser.parse(html: Self.feastBlockFixture)
        // Only the two real prose paragraphs survive, in document order.
        #expect(blocks.count == 2)
        let texts = blocks.map { block -> String in
            switch block {
            case .paragraph(let value), .heading(_, let value): return text(value)
            default: return ""
            }
        }
        // The orphan "Summarize and Save…" heading does not render.
        #expect(!texts.contains { $0.contains("Summarize and Save") })
        #expect(!texts.contains { $0.contains("Trusted Source") })
        #expect(texts.first?.contains("Intro prose") == true)
        #expect(texts.last?.contains("Closing prose") == true)
        // No Feast SEO-button link leaks into any run.
        let feastHosts: Set<String> = ["chatgpt.com", "www.google.com", "www.perplexity.ai", "x.com"]
        #expect(!paragraphLinks(blocks).contains { feastHosts.contains($0.host ?? "") })
        // The genuine recipe links in the surrounding prose ARE preserved.
        let kept = paragraphLinks(blocks).map(\.absoluteString)
        #expect(kept.contains("https://www.dutchovendaddy.com/dutch-oven-chili/"))
        #expect(kept.contains("https://www.dutchovendaddy.com/peach-cobbler/"))
    }

    // MARK: - Depth-balanced div removal

    @Test func removeDivBlockStripsRenderableNestedContent() {
        // A Feast block wrapping renderable prose: the depth-balanced removal
        // must drop the inner <p>, not stop at the first nested </div>.
        let html = """
            <p>Before.</p>\
            <div class="feast-ai-buttons-block"><div class="wp-block-buttons">\
            <p>AI prompt that must not render.</p></div></div>\
            <p>After.</p>
            """
        let stripped = ArticleHTMLParser.removeDivBlock(withClassToken: "feast-ai-buttons-block", from: html)
        #expect(!stripped.contains("must not render"))
        #expect(stripped.contains("Before."))
        #expect(stripped.contains("After."))
        // End-to-end: the inner prose does not survive into parsed blocks.
        let parts = ArticleHTMLParser.parse(html: html).compactMap { block -> String? in
            if case .paragraph(let value) = block { return text(value) }
            return nil
        }
        #expect(parts.joined(separator: "|") == "Before.|After.")
    }

    @Test func removeDivBlockKeepsNonMatchingDivs() {
        let html = #"<div class="wp-block-group"><p>Kept.</p></div>"#
        let stripped = ArticleHTMLParser.removeDivBlock(withClassToken: "feast-ai-buttons-block", from: html)
        #expect(stripped == html)
    }

    // MARK: - Heading removal across text variants

    @Test func removesSummarizeHeadingAcrossTextVariants() {
        // The visible text varies ("…the Recipe" / "…the Method"); the
        // WP-generated `summarize-and-save` anchor id is the stable signature.
        for variant in ["Recipe", "Method"] {
            let html = """
                <h3 class="wp-block-heading" id="h-summarize-and-save-the-\(variant.lowercased())">\
                Summarize and Save the \(variant)</h3><p>Kept body.</p>
                """
            #expect(ArticleHTMLParser.parse(html: html) == [.paragraph(AttributedString("Kept body."))])
        }
    }

    @Test func keepsHeadingsWithoutTheFeastAnchor() {
        // A real content heading whose id merely starts with "summarize" but is
        // not the Feast anchor must NOT be stripped.
        let html = "<h2 id=\"summary\">Recipe Summary</h2><p>Body.</p>"
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.first == .heading(level: 2, text: AttributedString("Recipe Summary")))
        #expect(blocks.count == 2)
    }
}

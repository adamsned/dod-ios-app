import Foundation
import Testing

@testable import DODSupport

/// Malformed-tag robustness tests for ``ArticleHTMLParser``.
///
/// Unclosed tags, nested structures, empty blocks, and whitespace-only content
/// must degrade gracefully: the parser skips malformed blocks while preserving
/// valid content that follows, and never crashes.
@Suite("ArticleHTMLParser malformed tags (robustness)")
struct ArticleHTMLParserMalformedTagsTests {

    private func text(_ value: AttributedString) -> String { String(value.characters) }

    // MARK: - Unclosed tags

    /// An unclosed `<figure>` tag without a matching `</figure>`. The parser's
    /// `sliceUntilMatchingClose` falls back to end-of-input, finding the `<img>`
    /// and emitting an image block (graceful degradation — content is extracted).
    @Test func unclosedFigureTagEmitsImage() throws {
        let html = """
            <figure>
            <img src="https://example.com/unclosed-fig.jpg" alt="Unclosed figure">
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let imageCount = blocks.filter {
            if case .image = $0 { return true }
            return false
        }.count
        #expect(imageCount == 1)
    }

    /// An unclosed `<p>` followed immediately by another `<p>`. The
    /// `sliceSimpleClose` for the first paragraph reads until the FIRST `</p>` found,
    /// which is the closing tag of the second paragraph. This means the first
    /// paragraph's inner text includes the unclosed second `<p>` tag itself,
    /// and only ONE paragraph block emits (the second one, with everything up to
    /// its closing tag as its content — a malformed but gracefully-handled edge case).
    @Test func unclosedParagraphFollowedByAnotherEmitsOnlySecond() {
        let html = """
            <p>First paragraph without closing tag
            <p>Second paragraph.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 1)
    }

    /// An unclosed `<figcaption>` inside a `<figure>`. The `figcaptionText`
    /// function guards on FINDING the opening tag, the closing `>`, AND the
    /// closing `</figcaption>` tag. If ANY of these guards fail, the function
    /// returns `nil`. So an unclosed figcaption results in an image block with
    /// `caption: nil`, not a partial caption.
    @Test func unclosedFigcaptionInsideFigureEmitsImageWithNilCaption() throws {
        let html = """
            <figure>
            <img src="https://example.com/fig.jpg" alt="Image">
            <figcaption>This caption is not closed
            </figure>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        guard case .image(let url, let caption) = blocks[0] else {
            Issue.record("expected an image block")
            return
        }
        #expect(url.absoluteString == "https://example.com/fig.jpg")
        #expect(caption == nil)
    }

    // MARK: - Nested figures

    /// A `<figure>` nested inside another `<figure>`. The outer figure's
    /// `sliceUntilMatchingClose` depth-tracks nested `<figure>` tags to find
    /// the true matching close. The first `<img>` in the body is used, which
    /// is the inner one, so one image should emit.
    @Test func nestedFigureInsideFigureEmitsOneImage() throws {
        let html = """
            <figure>
            <figure>
            <img src="https://example.com/inner.jpg" alt="Inner">
            </figure>
            </figure>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        guard case .image(let url, _) = blocks[0] else {
            Issue.record("expected an image block")
            return
        }
        #expect(url.absoluteString == "https://example.com/inner.jpg")
    }

    /// Two `<img>` tags in nested `<figure>` structures: outer has one, inner
    /// has another. The outer figure's slicing finds its first `<img>` (which
    /// is at the body start, not inside the inner `<figure>`), not the inner
    /// figure's image.
    @Test func outerFigureWithImageAndNestedFigureYieldsOuterImage() throws {
        let html = """
            <figure>
            <img src="https://example.com/outer.jpg" alt="Outer">
            <figure><img src="https://example.com/inner.jpg" alt="Inner"></figure>
            </figure>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let images = blocks.compactMap { block -> URL? in
            guard case .image(let url, _) = block else { return nil }
            return url
        }
        #expect(images.count == 1)
        #expect(images[0].absoluteString == "https://example.com/outer.jpg")
    }

    // MARK: - Figure without image

    /// A `<figure>` tag with text but no `<img>` inside. The `figureBlock`
    /// function checks for the image and returns `nil` if missing, so no block
    /// should emit. The surrounding content must still parse.
    @Test func figureWithoutImageEmitsNothing() {
        let html = """
            <p>Before figure.</p>
            <figure>This is just text, no image.</figure>
            <p>After figure.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 2)
        #expect(paragraphs[0] == "Before figure.")
        #expect(paragraphs[1] == "After figure.")
        let imageCount = blocks.filter { if case .image = $0 { return true } else { return false } }.count
        #expect(imageCount == 0)
    }

    // MARK: - Multiple figcaptions

    /// A `<figure>` with multiple `<figcaption>` tags. The `figcaptionText`
    /// function uses `firstTagBody(named: "figcaption")`, which finds only the
    /// FIRST one. Only the first caption is used.
    @Test func multipleFigcaptionsUsesOnlyFirst() throws {
        let html = """
            <figure>
            <img src="https://example.com/multi-caption.jpg" alt="Multi">
            <figcaption>First caption.</figcaption>
            <figcaption>Second caption (should be ignored).</figcaption>
            </figure>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        guard case .image(_, let caption) = blocks[0] else {
            Issue.record("expected an image block")
            return
        }
        #expect(caption == "First caption.")
    }

    // MARK: - Empty blocks

    /// Empty `<h2>` tag (no content). The parser's `textBlock` function checks
    /// `guard !text.runs.isEmpty`, so an empty heading should not emit a block.
    @Test func emptyHeadingEmitsNothing() {
        let html = """
            <p>Before.</p>
            <h2></h2>
            <p>After.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 2)
        let headingCount = blocks.filter { if case .heading = $0 { return true } else { return false } }.count
        #expect(headingCount == 0)
    }

    /// Empty `<blockquote>` tag. The `blockquoteBlocks` function returns an empty
    /// array for an empty blockquote, so no block should emit.
    @Test func emptyBlockquoteEmitsNothing() {
        let html = """
            <p>Before.</p>
            <blockquote></blockquote>
            <p>After.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 2)
    }

    /// Empty `<ul>` tag (no `<li>` children). The `listBlock` function returns
    /// `nil` when items are empty, so no block should emit.
    @Test func emptyListEmitsNothing() {
        let html = """
            <p>Before.</p>
            <ul></ul>
            <p>After.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 2)
        let listCount = blocks.filter { if case .list = $0 { return true } else { return false } }.count
        #expect(listCount == 0)
    }

    // MARK: - Whitespace-only blocks

    /// A `<figure>` containing only whitespace (no `<img>`). The whitespace is
    /// trimmed; the figure has no image, so `figureBlock` returns `nil` and no
    /// block should emit.
    @Test func whitespaceOnlyFigureEmitsNothing() {
        let html = """
            <p>Before.</p>
            <figure>

            </figure>
            <p>After.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 2)
        let imageCount = blocks.filter { if case .image = $0 { return true } else { return false } }.count
        #expect(imageCount == 0)
    }

    /// A `<p>` containing only whitespace. The inline parser trims whitespace,
    /// so an empty run should emit `nil` and no paragraph block.
    @Test func whitespaceOnlyParagraphEmitsNothing() {
        let html = """
            <p>Real text.</p>
            <p>   </p>
            <p>More real text.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 2)
        #expect(paragraphs[0] == "Real text.")
        #expect(paragraphs[1] == "More real text.")
    }
}

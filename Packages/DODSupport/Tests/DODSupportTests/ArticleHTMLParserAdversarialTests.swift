import Foundation
import Testing

@testable import DODSupport

/// Adversarial edge-case robustness tests for ``ArticleHTMLParser``.
///
/// Mixed-case tags, combined hidden-block markers, HTML comment stripping,
/// and malformed inline content must be handled gracefully without crashes
/// or content leaks.
@Suite("ArticleHTMLParser edge-case robustness (adversarial)")
struct ArticleHTMLParserAdversarialTests {

    private func text(_ value: AttributedString) -> String { String(value.characters) }

    // MARK: - Mixed-case tags

    /// `<figure>`, `<img>`, and `<figcaption>` tags written in mixed case:
    /// `<FiGuRe>`, `<IMG>`, `<FiGcApTiOn>`. The parser uses `.caseInsensitive`
    /// option for range searches, so these should be recognized and parsed
    /// identically to lowercase.
    @Test func mixedCaseFigureTagsAreRecognized() throws {
        let html = """
            <FiGuRe>
            <IMG src="https://example.com/mixed.jpg" alt="Mixed case">
            <FiGcApTiOn>Mixed case caption.</FiGcApTiOn>
            </FiGuRe>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        guard case .image(let url, let caption) = blocks[0] else {
            Issue.record("expected an image block")
            return
        }
        #expect(url.absoluteString == "https://example.com/mixed.jpg")
        #expect(caption == "Mixed case caption.")
    }

    /// Mixed-case paragraph and heading tags: `<P>`, `<H2>`. Should be parsed
    /// as regular blocks.
    @Test func mixedCaseParagraphAndHeadingTags() {
        let html = """
            <H2>Mixed Case Heading</H2>
            <P>Mixed case paragraph text.</P>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 2)
        if case .heading(let level, let text) = blocks[0] {
            #expect(level == 2)
            #expect(text == "Mixed Case Heading")
        } else {
            Issue.record("expected a heading block")
        }
        if case .paragraph(let text) = blocks[1] {
            #expect(text == "Mixed case paragraph text.")
        } else {
            Issue.record("expected a paragraph block")
        }
    }

    // MARK: - Hidden blocks combined

    /// A `<div>` marked hidden with BOTH `display:none` AND `visibility:hidden`
    /// in the same style attribute. Both are full-hide CSS values; the parser's
    /// `styleHidesElement` returns true if EITHER is present, so this div should
    /// be stripped entirely. Any images inside must not emit.
    @Test func displayNoneAndVisibilityHiddenCombinedYieldsNoImage() {
        let html = """
            <div style="display:none; visibility:hidden">
            <img src="https://example.com/doubly-hidden.jpg" alt="Hidden">
            </div>
            <p>Visible text.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let imageCount = blocks.filter { if case .image = $0 { return true } else { return false } }.count
        #expect(imageCount == 0)
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 1)
        #expect(paragraphs[0] == "Visible text.")
    }

    /// A `<div>` with `visibility:hidden !important` (the force-hidden variant
    /// covered by DUT-958). The parser should recognize this as a full hide and
    /// strip the div, even with the `!important` flag.
    @Test func visibilityHiddenImportantYieldsNoImage() {
        let html = """
            <div style="visibility:hidden !important">
            <img src="https://example.com/vis-hidden-important.jpg" alt="Hidden">
            </div>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let imageCount = blocks.filter { if case .image = $0 { return true } else { return false } }.count
        #expect(imageCount == 0)
    }

    // MARK: - Comment stripping before parsing

    /// An `<img>` tag inside an HTML comment. Comments are stripped BEFORE the
    /// block scan (via `HTMLSanitizer.strippingComments`), so the image inside
    /// should never reach the parser and no image block should emit.
    @Test func imgInsideCommentDoesNotEmit() {
        let html = """
            <p>Before.</p>
            <!-- This is a comment with an img tag:
                 <img src="https://example.com/commented-out.jpg" alt="Commented">
                 More comment text. -->
            <p>After.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let imageCount = blocks.filter { if case .image = $0 { return true } else { return false } }.count
        #expect(imageCount == 0)
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 2)
    }

    /// A `<figure>` tag (complete with `<img>` and `<figcaption>`) inside a
    /// comment. The entire figure should be stripped before parsing, so no image
    /// block should emit.
    @Test func figureInsideCommentDoesNotEmit() {
        let html = """
            <p>Before.</p>
            <!-- <figure><img src="https://example.com/commented.jpg" alt="Commented"><figcaption>Commented caption.</figcaption></figure> -->
            <p>After.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let imageCount = blocks.filter { if case .image = $0 { return true } else { return false } }.count
        #expect(imageCount == 0)
    }

    // MARK: - Malformed attributes and tag closures

    /// An `<img>` tag with a malformed attribute: the tag doesn't close (no `>`).
    /// The inline tag scan in `inlineAttributedString` handles a lone `<` by
    /// emitting it as a literal character and advancing, preventing hangs. A
    /// malformed img tag should be skipped but subsequent content should parse.
    @Test func malformedImgWithoutClosingBracketDoesNotHang() {
        let html = """
            <img src="https://example.com/ok.jpg" alt="OK">
            <p>Text after malformed img tag</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        // The first img should parse correctly.
        let imageCount = blocks.filter { if case .image = $0 { return true } else { return false } }.count
        #expect(imageCount == 1)
        // The paragraph after should still be emitted.
        let paragraphs = blocks.compactMap { block -> String? in
            guard case .paragraph(let body) = block else { return nil }
            return text(body)
        }
        #expect(paragraphs.count == 1)
    }

    /// A `<figcaption>` tag whose text contains what looks like a tag (e.g.
    /// `<div>`). The inline parser finds the `<` and searches for `>`, treating
    /// the content as a tag. `div` is not an inline formatting tag (only `strong`,
    /// `em`, `a`, `br` are recognized), so the tag is skipped entirely. The
    /// result is that `<div>` is stripped out; text before/after is preserved
    /// with the space boundary between text runs intact.
    @Test func figcaptionWithAngleBracketTagParsesGracefully() throws {
        let html = """
            <figure>
            <img src="https://example.com/code.jpg" alt="Code">
            <figcaption>Use <div> like this</figcaption>
            </figure>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        guard case .image(_, let caption) = blocks[0] else {
            Issue.record("expected an image block")
            return
        }
        // The caption should exist (figcaption was closed properly).
        #expect(caption != nil)
        // The <div> tag is stripped out. Text runs preserve their boundary
        // spaces, so "Use " + " like this" leaves two spaces between words.
        #expect(caption == "Use  like this")
    }

    /// A paragraph with text that looks like HTML but contains an unmatched
    /// angle bracket (e.g. "Cook for <5 minutes"). The inline parser should
    /// emit the `<` as a literal character when it finds no closing `>` in
    /// the remainder of the text, preventing hangs (per DOD-ART-1).
    @Test func paragraphWithUnmatchedAngleBracketParsesGracefully() {
        let html = """
            <p>Cook for <5 minutes on high heat.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        #expect(blocks.count == 1)
        if case .paragraph(let text) = blocks[0] {
            let content = String(text.characters)
            #expect(content.contains("<5"))
            #expect(content.contains("minutes"))
        } else {
            Issue.record("expected a paragraph block")
        }
    }
}

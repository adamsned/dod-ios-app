import Foundation
import Testing

@testable import DODSupport

/// L1 unit tests for hidden-block stripping (DUT-918b).
///
/// The DPSP / Grow Social plugin injects a `display:none` Pinterest share-card
/// `<div>` into every post body.  ``ArticleHTMLParser/removeHiddenBlocks(from:)``
/// strips these before the block scan so the collage images never reach the
/// native render.  Tests cover both removal triggers (class token and
/// inline style), depth-balanced close-tag matching, style-value whitespace
/// tolerance, and regression-guard that visible content is never discarded.
@Suite("ArticleHTMLParser hidden-block stripping (DUT-918b)") struct ArticleHTMLParserHiddenBlockTests {

    // MARK: - Helpers

    /// Image URLs emitted by the parser for `html`.
    private func imageURLs(from html: String) -> [URL] {
        ArticleHTMLParser.parse(html: html).compactMap { block -> URL? in
            guard case .image(let url, _) = block else { return nil }
            return url
        }
    }

    // MARK: - Class-token trigger

    @Test func dpspClassTokenYieldsNoImageBlock() {
        // The exact markup the DPSP/Grow Social plugin emits on dutchovendaddy.com.
        let html = """
            <div class="dpsp-post-pinterest-image-hidden" style="display: none;">\
            <img src="/pin.jpg" alt="Social media image for X"></div>
            """
        #expect(imageURLs(from: html).isEmpty)
    }

    @Test func dpspClassTokenInMultiClassAttributeYieldsNoImageBlock() {
        // Class list has sibling tokens alongside the dpsp token.
        let html = """
            <div class="social-share dpsp-post-pinterest-image-hidden extra-class" style="display: none;">\
            <img src="https://example.com/collage.jpg" alt="Collage"></div>
            """
        #expect(imageURLs(from: html).isEmpty)
    }

    // MARK: - Inline style trigger

    @Test func displayNoneStyleYieldsNoImageBlock() {
        // A bare `display:none` div (no dpsp class) must also be stripped.
        let html = """
            <div style="display:none"><img src="https://example.com/hidden.jpg"></div>
            """
        #expect(imageURLs(from: html).isEmpty)
    }

    @Test func displayNoneWithSpacesYieldsNoImageBlock() {
        // Whitespace around `:` and the value: `display : none`.
        let html = """
            <div style="display : none"><img src="https://example.com/spaced.jpg"></div>
            """
        #expect(imageURLs(from: html).isEmpty)
    }

    @Test func displayNoneWithLeadingSpaceYieldsNoImageBlock() {
        // Extra space before `none`: `display: none`.
        let html = """
            <div style="display: none"><img src="https://example.com/spaced2.jpg"></div>
            """
        #expect(imageURLs(from: html).isEmpty)
    }

    @Test func displayNoneAmongOtherPropertiesYieldsNoImageBlock() {
        // `display:none` is one of several CSS properties in the style value.
        let html = """
            <div style="color: red; display : none ; font-size: 12px">\
            <img src="https://example.com/multi.jpg"></div>
            """
        #expect(imageURLs(from: html).isEmpty)
    }

    // MARK: - Nested content inside hidden div

    @Test func hiddenDivContainingFigureYieldsNoBlock() {
        // A `<figure><img></figure>` nested inside the hidden div must not emit.
        let html = """
            <div class="dpsp-post-pinterest-image-hidden" style="display: none;">\
            <figure><img src="https://example.com/pin-figure.jpg" alt="Pinterest figure"></figure>\
            </div>
            """
        #expect(ArticleHTMLParser.parse(html: html).isEmpty)
    }

    @Test func visibleFigureAfterHiddenDivIsStillEmitted() {
        // The depth-matched close must not over-consume: the visible `<figure>`
        // that follows the hidden div must still produce an image block.
        let html = """
            <div class="dpsp-post-pinterest-image-hidden" style="display: none;">\
            <figure><img src="https://example.com/hidden-pin.jpg" alt="Hidden"></figure>\
            </div>\
            <figure><img src="https://example.com/real.jpg" alt="Real photo"></figure>
            """
        let urls = imageURLs(from: html)
        #expect(urls.count == 1)
        #expect(urls.first == URL(string: "https://example.com/real.jpg"))
    }

    @Test func deeplyNestedHiddenDivDoesNotOverConsume() {
        // Hidden div nests two levels of divs; the visible paragraph after must
        // still be emitted and the hidden img must be suppressed.
        let html = """
            <div style="display:none">\
            <div class="inner"><img src="https://example.com/deep.jpg"></div>\
            </div>\
            <p>Visible text.</p>
            """
        let blocks = ArticleHTMLParser.parse(html: html)
        let imageCount = blocks.filter {
            if case .image = $0 {
                return true
            }
            return false
        }.count
        let hasText = blocks.contains {
            if case .paragraph(let txt) = $0 {
                return String(txt.characters) == "Visible text."
            }
            return false
        }
        #expect(imageCount == 0)
        #expect(hasText)
    }

    // MARK: - Visible content is unaffected

    @Test func normalVisibleImgIsUnaffected() {
        let html = "<img src=\"https://example.com/normal.jpg\" alt=\"Normal\">"
        let urls = imageURLs(from: html)
        #expect(urls == [URL(string: "https://example.com/normal.jpg")])
    }

    @Test func normalVisibleFigureIsUnaffected() {
        let html = """
            <figure><img src="https://example.com/fig.jpg" alt="Figure"></figure>
            """
        let urls = imageURLs(from: html)
        #expect(urls == [URL(string: "https://example.com/fig.jpg")])
    }

    @Test func divWithoutHiddenMarkersIsUnaffected() {
        // A visible `<div>` wrapping a `<figure>` must pass through.
        let html = """
            <div class="wp-block-image">\
            <figure><img src="https://example.com/wp.jpg" alt="WP image"></figure>\
            </div>
            """
        let urls = imageURLs(from: html)
        #expect(urls == [URL(string: "https://example.com/wp.jpg")])
    }

    // MARK: - removeHiddenBlocks unit-level

    @Test func removeHiddenBlocksStripsOnlyHiddenDiv() {
        let html = """
            <p>Before.</p>\
            <div style="display:none"><img src="/gone.jpg"></div>\
            <p>After.</p>
            """
        let stripped = ArticleHTMLParser.removeHiddenBlocks(from: html)
        #expect(!stripped.contains("/gone.jpg"))
        #expect(stripped.contains("Before."))
        #expect(stripped.contains("After."))
    }

    @Test func removeHiddenBlocksKeepsNonHiddenDivs() {
        let html = #"<div class="wp-block-group"><p>Kept.</p></div>"#
        let stripped = ArticleHTMLParser.removeHiddenBlocks(from: html)
        #expect(stripped == html)
    }

    // MARK: - styleHasDisplayNone unit-level

    @Test func styleHasDisplayNoneMatchesVariants() {
        #expect(ArticleHTMLParser.styleHasDisplayNone(#" style="display:none""#))
        #expect(ArticleHTMLParser.styleHasDisplayNone(#" style="display: none""#))
        #expect(ArticleHTMLParser.styleHasDisplayNone(#" style="display : none""#))
        #expect(ArticleHTMLParser.styleHasDisplayNone(#" style="DISPLAY:NONE""#))
        #expect(ArticleHTMLParser.styleHasDisplayNone(#" style="color:red;display:none""#))
    }

    @Test func styleHasDisplayNoneDoesNotMatchOtherValues() {
        #expect(!ArticleHTMLParser.styleHasDisplayNone(#" style="display:block""#))
        #expect(!ArticleHTMLParser.styleHasDisplayNone(#" style="visibility:hidden""#))
        #expect(!ArticleHTMLParser.styleHasDisplayNone(#" class="display:none""#))
        #expect(!ArticleHTMLParser.styleHasDisplayNone(""))
    }
}

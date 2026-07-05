import Foundation
import Testing

@testable import DODSupport

/// L1 unit tests for ``ArticleHTMLParser`` lazy-load image-URL resolution.
///
/// Spec trace: DUT-582 / CL-314. Dutch Oven Daddy is WordPress with a lazy-load
/// plugin, so an `<img>`'s real photo URL is NOT in `src` (a `data:` URI or a
/// 1px spacer placeholder) but in `data-src` / `data-lazy-src` (single) or
/// `srcset` / `data-lazy-srcset` (candidate list). ``ReliableImage`` needs an
/// absolute `http(s)` URL, so the parser must resolve one — preferring the
/// lazy attributes, falling back to `srcset`, and normalizing protocol-relative
/// (`//`) and root-relative (`/wp-content/…`) sources against a base URL.
@Suite("ArticleHTMLParser image-URL resolution (DUT-582)") struct ArticleHTMLParserImageTests {

    private let baseString = "https://dutchovendaddy.com/recipes/dump-cake/"

    /// The URL of the single `.image` block in `blocks`, or nil.
    private func imageURL(_ blocks: [ArticleBlock]) -> URL? {
        guard blocks.count == 1, case .image(let url, _) = blocks[0] else { return nil }
        return url
    }

    /// Parse `html` with the shared recipe base URL, returning the image URL.
    private func imageURL(from html: String) throws -> URL? {
        let base = try #require(URL(string: baseString))
        return imageURL(ArticleHTMLParser.parse(html: html, baseURL: base))
    }

    @Test func prefersDataSrcWhenSrcIsDataURIPlaceholder() throws {
        // Lazy-load: src is a base64 1px placeholder, the real URL is in data-src.
        let html = """
            <img src="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" \
            data-src="https://dutchovendaddy.com/wp-content/uploads/hero.jpg" alt="Hero">
            """
        #expect(try imageURL(from: html) == URL(string: "https://dutchovendaddy.com/wp-content/uploads/hero.jpg"))
    }

    @Test func fallsBackToDataLazySrc() throws {
        // No usable src, no data-src — data-lazy-src carries the real URL.
        let html = """
            <img src="data:image/svg+xml,placeholder" \
            data-lazy-src="https://dutchovendaddy.com/wp-content/uploads/step-1.jpg" alt="Step 1">
            """
        #expect(try imageURL(from: html) == URL(string: "https://dutchovendaddy.com/wp-content/uploads/step-1.jpg"))
    }

    @Test func fallsBackToSrcsetWhenNoUsableSingleSource() throws {
        // Only a data: placeholder src + a srcset: pick the widest (last) entry.
        let html = """
            <img src="data:image/gif;base64,AAAA" \
            srcset="https://dutchovendaddy.com/wp-content/uploads/small-480w.jpg 480w, \
            https://dutchovendaddy.com/wp-content/uploads/large-1024w.jpg 1024w" alt="Srcset">
            """
        #expect(
            try imageURL(from: html) == URL(string: "https://dutchovendaddy.com/wp-content/uploads/large-1024w.jpg")
        )
    }

    @Test func fallsBackToDataLazySrcset() throws {
        let html = """
            <img src="data:image/gif;base64,AAAA" \
            data-lazy-srcset="https://dutchovendaddy.com/wp-content/uploads/a-300w.jpg 300w, \
            https://dutchovendaddy.com/wp-content/uploads/b-900w.jpg 900w" alt="Lazy srcset">
            """
        #expect(try imageURL(from: html) == URL(string: "https://dutchovendaddy.com/wp-content/uploads/b-900w.jpg"))
    }

    @Test func normalizesProtocolRelativeToHTTPS() throws {
        let html = "<img data-src=\"//dutchovendaddy.com/wp-content/uploads/pot.jpg\" alt=\"Pot\">"
        #expect(try imageURL(from: html) == URL(string: "https://dutchovendaddy.com/wp-content/uploads/pot.jpg"))
    }

    @Test func resolvesRootRelativeAgainstBaseURL() throws {
        let html = "<img data-src=\"/wp-content/uploads/relative.jpg\" alt=\"Relative\">"
        // Root-relative resolves against the base's host, not its path.
        #expect(try imageURL(from: html) == URL(string: "https://dutchovendaddy.com/wp-content/uploads/relative.jpg"))
    }

    @Test func plainAbsoluteSrcUnchanged() throws {
        // A normal absolute src with no lazy attributes is used as-is.
        let html = "<img src=\"https://example.com/plain.png\" alt=\"Plain\">"
        #expect(try imageURL(from: html) == URL(string: "https://example.com/plain.png"))
    }

    @Test func rootRelativeWithoutBaseURLIsSkipped() {
        // No base URL → a root-relative source can't become absolute → no block.
        #expect(ArticleHTMLParser.parse(html: "<img data-src=\"/wp-content/x.jpg\">").isEmpty)
    }

    @Test func garbageOrPlaceholderOnlyProducesNoBlock() {
        // Only a data: placeholder, no real candidate anywhere → no image block.
        #expect(ArticleHTMLParser.parse(html: "<img src=\"data:image/gif;base64,AAAA\" alt=\"x\">").isEmpty)
        // Empty everything.
        #expect(ArticleHTMLParser.parse(html: "<img data-src=\"\" srcset=\"\">").isEmpty)
    }
}

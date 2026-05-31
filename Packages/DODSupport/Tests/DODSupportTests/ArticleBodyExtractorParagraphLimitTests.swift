import Testing

@testable import DODSupport

/// L1 unit tests for the T-733 / CL-130 paragraph-cap behavior on
/// ``ArticleBodyExtractor/extractRecipeBlurb(html:paragraphLimit:)``.
///
/// Spec trace: US-4 amendment, AC-4.12 (amended), CL-130. Separate file
/// from the main `ArticleBodyExtractorTests` to keep both suites under
/// SwiftLint's `type_body_length` cap.
@Suite("ArticleBodyExtractor.extractRecipeBlurb paragraphLimit (T-733 / CL-130)")
struct ArticleBodyExtractorParagraphLimitTests {

    /// Long-form recipe with 5 intro paragraphs before the WPRM card: with
    /// the default `paragraphLimit: 2`, only the first 2 are returned.
    /// Paragraphs 3-5 are dropped, replicating the live-API case where
    /// long-form blog-style recipes have 30-40 intro `<p>` blocks before
    /// the recipe card.
    @Test func capsAtParagraphLimit() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>Paragraph one — the lead.</p>
            <p>Paragraph two — backstory.</p>
            <p>Paragraph three — dropped.</p>
            <p>Paragraph four — dropped.</p>
            <p>Paragraph five — dropped.</p>
            <div class="wprm-recipe-container"><p>card</p></div>
            </div>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html, paragraphLimit: 2)
        #expect(result.contains("Paragraph one"))
        #expect(result.contains("Paragraph two"))
        #expect(!result.contains("Paragraph three"))
        #expect(!result.contains("Paragraph four"))
        #expect(!result.contains("Paragraph five"))
        // Card content still excluded by the WPRM crop.
        #expect(!result.contains("card"))
    }

    /// Source has fewer paragraphs than the cap: returns what it has (no
    /// padding). A 1-paragraph fixture with `limit: 2` returns the single
    /// paragraph unmodified.
    @Test func returnsAvailableWhenFewerThanLimit() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>Only paragraph.</p>
            <div class="wprm-recipe-container"><p>card</p></div>
            </div>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html, paragraphLimit: 2)
        #expect(result.contains("Only paragraph."))
        #expect(!result.contains("card"))
    }

    /// Degenerate-but-safe: `paragraphLimit: 0` returns empty regardless of
    /// what the entry-content contains.
    @Test func returnsEmptyForZeroLimit() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>Some prose.</p>
            <p>More prose.</p>
            </div>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html, paragraphLimit: 0)
        #expect(result.isEmpty)
    }

    /// Mixed block sequence: headings / images / lists that sit BEFORE the
    /// Nth `<p>` boundary are preserved as context for the surrounding
    /// paragraphs. With `[paragraph, heading, paragraph, image, paragraph]`
    /// and `limit: 2`, the result contains the first 2 paragraphs PLUS the
    /// heading between them; the trailing image and 3rd paragraph are
    /// dropped.
    @Test func preservesNonParagraphsBeforeLimit() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>First paragraph.</p>
            <h2>Section heading</h2>
            <p>Second paragraph.</p>
            <img src="https://example.com/x.png" alt="x">
            <p>Third paragraph — dropped.</p>
            <div class="wprm-recipe-container"><p>card</p></div>
            </div>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html, paragraphLimit: 2)
        #expect(result.contains("First paragraph."))
        #expect(result.contains("Section heading"))
        #expect(result.contains("Second paragraph."))
        #expect(!result.contains("Third paragraph"))
        // The `<img>` between paragraph 2 and 3 is dropped because the cut
        // happens at the `</p>` close tag of paragraph 2 — anything after
        // that close tag is gone.
        #expect(!result.contains("example.com/x.png"))
    }
}

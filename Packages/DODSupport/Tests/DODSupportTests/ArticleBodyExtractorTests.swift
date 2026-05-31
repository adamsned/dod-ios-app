import Testing

@testable import DODSupport

/// L1 unit tests for ``ArticleBodyExtractor``.
///
/// Spec trace: US-37, CL-63, AC-37.7. The extractor's job is to walk the
/// rendered WordPress HTML page and pull a sanitized plain-text article
/// body, with a fallback chain of `entry-content` → `<article>` → `<main>`
/// → `<body>` → empty string. Each fixture pins one branch of the chain.
@Suite("ArticleBodyExtractor.extract") struct ArticleBodyExtractorTests {

    @Test func extractsEntryContentDiv() {
        let html = """
            <html><body>
            <header>chrome</header>
            <div class="entry-content">
            <p>Welcome to my roundup of the best dutch oven recipes.</p>
            <p>Here are my 30 favorites.</p>
            </div>
            <footer>also chrome</footer>
            </body></html>
            """
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.contains("Welcome to my roundup"))
        #expect(result.contains("30 favorites"))
        // Header/footer chrome must NOT be in the result — the
        // entry-content slice is preferred over the body fallback.
        #expect(!result.contains("chrome"))
    }

    /// DOD-ART-1: `extractContentHTML` is the rich-rendering counterpart to
    /// `extract` — it returns the entry-content slice as **HTML** (tags
    /// intact) so ``ArticleHTMLParser`` can render native blocks, where
    /// `extract` strips everything to plain text. Same fallback chain.
    @Test func extractContentHTMLKeepsTags() {
        let html = """
            <html><body>
            <header>chrome</header>
            <div class="entry-content">
            <h2>Best Recipes</h2>
            <p>Welcome to my <strong>roundup</strong>.</p>
            <figure><img src="https://example.com/a.jpg" alt="A"></figure>
            </div>
            <footer>also chrome</footer>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractContentHTML(html: html)
        // Structural HTML is preserved (unlike `extract`, which strips it).
        #expect(result.contains("<h2>Best Recipes</h2>"))
        #expect(result.contains("<strong>roundup</strong>"))
        #expect(result.contains("<img"))
        // Still scoped to entry-content — page chrome excluded.
        #expect(!result.contains("chrome"))
        // Contrast: the plain-text path on the same input drops the tags.
        #expect(!ArticleBodyExtractor.extract(html: html).contains("<h2>"))
    }

    @Test func entryContentWinsOverArticle() {
        // Both wrappers present; entry-content is the canonical WP body,
        // so it should win the priority lookup.
        let html = """
            <article>
            <p>article-tag body.</p>
            </article>
            <div class="entry-content">
            <p>entry-content body.</p>
            </div>
            """
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.contains("entry-content body."))
        #expect(!result.contains("article-tag body."))
    }

    @Test func falsBackToArticleTagWhenNoEntryContent() {
        let html = """
            <html><body>
            <header>nav links</header>
            <article>
            <h1>Article Title</h1>
            <p>Article body paragraph.</p>
            </article>
            </body></html>
            """
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.contains("Article body paragraph"))
        #expect(!result.contains("nav links"))
    }

    @Test func fallsBackToMainTagWhenNoEntryContentOrArticle() {
        let html = """
            <html><body>
            <header>navigation</header>
            <main>
            <h2>Main heading</h2>
            <p>Main content paragraph.</p>
            </main>
            </body></html>
            """
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.contains("Main content paragraph"))
        #expect(!result.contains("navigation"))
    }

    @Test func fallsBackToBodyWhenNoSemanticContainer() {
        let html = """
            <html>
            <head><title>Doc</title></head>
            <body>
            <p>Just plain body text.</p>
            </body>
            </html>
            """
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.contains("Just plain body text"))
    }

    @Test func returnsEmptyStringWhenNoContainersMatch() {
        // HTML is malformed enough that none of the four containers can be
        // found. Returns empty so the view model transitions to the
        // terminal `.unavailable` path.
        let html = "<html><head><title>x</title></head>"
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.isEmpty)
    }

    @Test func entryContentToleratesAdditionalClasses() {
        // WP often produces `class="entry-content single-post-content"` —
        // the token match must still find `entry-content` in the
        // whitespace-delimited class list.
        let html = """
            <div class="entry-content single-post-content full-width">
            <p>Body text here.</p>
            </div>
            """
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.contains("Body text here"))
    }

    @Test func entryContentToleratesSingleQuotedAttributes() {
        // Some WP themes single-quote class attribute values.
        let html = """
            <div class='entry-content'>
            <p>Single-quoted body.</p>
            </div>
            """
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.contains("Single-quoted body"))
    }

    @Test func entryContentHandlesNestedDivs() {
        // The entry-content div contains other nested divs; the extractor
        // must walk the depth and find the matching close.
        let html = """
            <div class="entry-content">
            <p>Outer paragraph.</p>
            <div class="inner-container">
            <p>Inner paragraph.</p>
            </div>
            <p>After inner.</p>
            </div>
            <div>Outside, should be excluded.</div>
            """
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.contains("Outer paragraph"))
        #expect(result.contains("Inner paragraph"))
        #expect(result.contains("After inner"))
        #expect(!result.contains("Outside, should be excluded"))
    }

    @Test func extractedTextIsHTMLSanitized() {
        // Entities + tags must be cleaned via HTMLSanitizer — the extractor
        // never returns raw HTML.
        let html = """
            <div class="entry-content">
            <p>Sweet &amp; salty &mdash; <strong>perfect.</strong></p>
            </div>
            """
        let result = ArticleBodyExtractor.extract(html: html)
        #expect(result.contains("Sweet & salty — perfect."))
        #expect(!result.contains("<strong>"))
        #expect(!result.contains("&amp;"))
    }
}

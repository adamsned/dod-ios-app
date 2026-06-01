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

    // MARK: - extractRecipeBlurb (T-732 / CL-129 / AC-4.12)

    /// Recipe page with a WPRM card: the blurb extractor returns only the
    /// narrative HTML preceding the `<div class="wprm-recipe-container">`
    /// card. The structured ingredient/instruction content inside the card
    /// stays out of the blurb so the rich-rendered blurb in the recipe
    /// detail view doesn't duplicate what AC-4.2 / AC-4.3 already render.
    @Test func extractRecipeBlurbCropsAtWPRMCard() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>This is the blurb above the recipe card.</p>
            <p>Another paragraph of the blurb.</p>
            <div class="wprm-recipe-container wprm-recipe-template-default">
            <h2>Recipe Card Title</h2>
            <ul><li>1 cup flour</li><li>1 tsp salt</li></ul>
            <ol><li>Mix.</li><li>Bake.</li></ol>
            </div>
            <p>Notes after the card.</p>
            </div>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html)
        #expect(result.contains("This is the blurb above the recipe card."))
        #expect(result.contains("Another paragraph of the blurb."))
        // Recipe-card structured content must NOT leak into the blurb.
        #expect(!result.contains("wprm-recipe-container"))
        #expect(!result.contains("Recipe Card Title"))
        #expect(!result.contains("1 cup flour"))
        #expect(!result.contains("Notes after the card."))
    }

    /// No WPRM card present (rare — custom theme or non-WPRM recipe page):
    /// fall back to returning the entire `entry-content` slice so the
    /// expanded blurb still has prose to render.
    @Test func extractRecipeBlurbReturnsFullContentWhenNoWPRMCard() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>A blurb without a WPRM card.</p>
            <p>More blurb prose.</p>
            </div>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html)
        #expect(result.contains("A blurb without a WPRM card."))
        #expect(result.contains("More blurb prose."))
    }

    /// No `entry-content` slice exists at all (the post page is genuinely
    /// unrenderable): returns the empty string so the view falls back to the
    /// collapsed-only state.
    @Test func extractRecipeBlurbReturnsEmptyWhenNoEntryContent() {
        let html = "<html><body><p>No entry content wrapper.</p></body></html>"
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html)
        #expect(result.isEmpty)
    }

    /// WPRM card class can appear in any order in the `class=` list — the
    /// class-token matcher must tolerate sibling classes.
    @Test func extractRecipeBlurbHandlesWPRMCardWithSiblingClasses() {
        let html = """
            <div class="entry-content">
            <p>Blurb prose.</p>
            <div class="foo wprm-recipe-container bar"><p>Recipe card stuff.</p></div>
            </div>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html)
        #expect(result.contains("Blurb prose."))
        #expect(!result.contains("Recipe card stuff."))
    }

    // MARK: - extractRecipeBlurb broadened boundary detection (T-735 / CL-132)

    /// T-735 / CL-132: Tasty Recipes plugin emits the recipe card as
    /// `<div class="tasty-recipes ...">`. The broadened boundary scanner
    /// recognizes the `tasty-recipes` class token in addition to WPRM's
    /// `wprm-recipe-container`, so a recipe page using Tasty instead of
    /// WPRM also gets a clean pre-card crop. Live-API audit on 2026-05-31
    /// found zero recipes using Tasty on `dutchovendaddy.com`; this is
    /// defensive coverage for future plugin migrations or guest posts.
    @Test func extractRecipeBlurbCropsAtTastyRecipesBoundary() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>This is the blurb above a Tasty Recipes card.</p>
            <div class="tasty-recipes tasty-recipes-modern">
            <h2>Tasty Card Title</h2>
            <ul><li>1 cup flour</li></ul>
            </div>
            </div>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html)
        #expect(result.contains("This is the blurb above a Tasty Recipes card."))
        // Tasty-card structured content must NOT leak into the blurb.
        #expect(!result.contains("Tasty Card Title"))
        #expect(!result.contains("1 cup flour"))
    }

    /// T-735 / CL-132: Meal Vista plugin emits the card as
    /// `<div class="mv-create ...">`. Same broadened-boundary contract —
    /// the blurb crops at the first MV card boundary.
    @Test func extractRecipeBlurbCropsAtMealVistaBoundary() {
        let html = """
            <html><body>
            <div class="entry-content">
            <p>Intro before a Meal Vista card.</p>
            <div class="mv-create mv-create-card">
            <p>Meal Vista card body.</p>
            </div>
            </div>
            </body></html>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html)
        #expect(result.contains("Intro before a Meal Vista card."))
        #expect(!result.contains("Meal Vista card body."))
    }

    /// T-735 / CL-132: when MULTIPLE recipe-card boundary tokens appear
    /// in the same page, the extractor crops at the FIRST one regardless
    /// of which plugin emitted it. Verifies the
    /// ``recipeCardBoundaryTokens`` priority-ordered scan picks the
    /// earliest boundary, not the first one by token-list priority.
    @Test func extractRecipeBlurbCropsAtEarliestBoundaryRegardlessOfPlugin() {
        // Tasty appears BEFORE WPRM in the HTML — even though WPRM is
        // first in the priority list, the FIRST boundary in document
        // order wins (the user-visible blurb is everything before any
        // recipe card, period).
        let html = """
            <div class="entry-content">
            <p>Blurb prose.</p>
            <div class="tasty-recipes">Tasty card body.</div>
            <p>Between cards (should NOT appear).</p>
            <div class="wprm-recipe-container">WPRM body.</div>
            </div>
            """
        let result = ArticleBodyExtractor.extractRecipeBlurb(html: html)
        #expect(result.contains("Blurb prose."))
        #expect(!result.contains("Between cards"))
        #expect(!result.contains("Tasty card body."))
        #expect(!result.contains("WPRM body."))
    }
}

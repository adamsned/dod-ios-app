import XCTest

/// DUT-917/918/918b/957/958 — L5 E2E regression suite for ARTICLE (blog-post)
/// rendering.
///
/// The fixture article ("Dutch Oven Care Guide", id 99001,
/// ``E2EFixtures/articles``) provides hermetic coverage of the surfaces that
/// had five recent production bugs:
///
/// - **DUT-918**: `<figcaption>` text renders as a visible caption.
/// - **DUT-917**: `alt` attribute text does NOT become a visible caption — it
///   is accessibility text only (`ArticleHTMLParser.imageBlock` ignores `alt`).
/// - **DUT-918b**: a hidden `<div class="dpsp-post-pinterest-image-hidden"
///   style="display:none">` wrapper (DPSP / Grow Social plugin) is stripped by
///   `ArticleHTMLParser.removeHiddenBlocks` so the images inside never render.
///
/// Journey shape:
/// 1. Hermetic launch → feed shows the article card by title.
/// 2. Tap the card → `RecipeDetailViewModel.classifyPage` finds no
///    `@type: Recipe` JSON-LD → falls through to `classifyAsArticle` →
///    `.article` → `ArticleDetailView` renders.
/// 3. Assert visible content (figcaption, paragraph).
/// 4. Assert absent content (leaked alt-text, hidden-block caption).
@MainActor
final class ArticleRenderingJourneysE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Journey: article opens from feed and renders correctly

    /// Open the fixture article from the feed → article detail hydrates via
    /// `ArticleHTMLParser` → visible figcaption and paragraph render → leaked
    /// alt-text and hidden-Pinterest-block caption are absent.
    func test_article_opens_from_feed_and_renders_body_blocks() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        // The fixture article is appended after the 3 recipe fixtures in the
        // unfiltered /wp/v2/posts list, so it appears as a feed card.
        // Use the stable `dod.feed.card` identifier + a title-CONTAINS predicate
        // to target it regardless of its position in the list.
        let articleCardPredicate = NSPredicate(
            format: "identifier == 'dod.feed.card' AND label CONTAINS 'Dutch Oven Care Guide'"
        )
        let articleCard = app.buttons.matching(articleCardPredicate).firstMatch
        XCTAssertTrue(
            articleCard.waitForExistence(timeout: 15),
            "feed should surface the article fixture card 'Dutch Oven Care Guide'"
        )
        articleCard.tap()

        // The article detail screen renders via ArticleDetailView — NOT the
        // recipe screen (no Ingredients header, per CL-63 decision 5).
        // ArticleBlocksView carries the stable 'Article body' accessibility
        // label (set in ArticleDetailView.articleBody via .accessibilityLabel).
        let articleBody = app.otherElements.matching(
            NSPredicate(format: "label == 'Article body'")
        ).firstMatch
        XCTAssertTrue(
            articleBody.waitForExistence(timeout: 15),
            "ArticleDetailView should render 'Article body' after article classification"
        )

        // POSITIVE — DUT-918: the <figcaption> text renders as a visible
        // caption below the figure image. ArticleHTMLParser.figureBlock
        // reads figcaptionText(in:) and stores it as the .image caption;
        // ArticleBlocksView renders it as a Text element.
        let figCaption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'A seasoned Dutch oven'")
        ).firstMatch
        XCTAssertTrue(
            figCaption.exists,
            "visible <figcaption> 'A seasoned Dutch oven' must render as caption text (DUT-918)"
        )

        // POSITIVE: paragraph body text renders.
        let paragraph = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Seasoning your Dutch oven'")
        ).firstMatch
        XCTAssertTrue(
            paragraph.exists,
            "article paragraph text should render in the body"
        )

        // NEGATIVE — DUT-917: the alt attribute on a bare <img> must NOT
        // become a visible caption text element. ArticleHTMLParser.imageBlock
        // always sets caption to nil (alt is accessibility text, not reader
        // text), so 'Social media image' must not appear in any staticText.
        let leakedAltAsText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Social media image'")
        )
        XCTAssertEqual(
            leakedAltAsText.count,
            0,
            "alt text 'Social media image' must NOT appear as visible caption text (DUT-917)"
        )

        // NEGATIVE — DUT-918b: the hidden Pinterest div's figcaption
        // ('Collage Caption') must NOT render. ArticleHTMLParser.removeHiddenBlocks
        // strips the entire dpsp-post-pinterest-image-hidden wrapper (and all
        // children including the <figcaption>) before scanBlocks runs.
        let hiddenBlockCaption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Collage Caption'")
        )
        XCTAssertEqual(
            hiddenBlockCaption.count,
            0,
            "hidden Pinterest block caption must NOT render (DUT-918b: removeHiddenBlocks)"
        )
    }

    // MARK: - Journey: article detail does NOT show recipe chrome

    /// Opening an article must NOT render the Ingredients header or the
    /// Cook Mode CTA — articles carry no recipe data (CL-63 decision 5).
    func test_article_detail_has_no_recipe_chrome() {
        app.launchForE2E()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "tab bar should appear"
        )

        let articleCardPredicate = NSPredicate(
            format: "identifier == 'dod.feed.card' AND label CONTAINS 'Dutch Oven Care Guide'"
        )
        let articleCard = app.buttons.matching(articleCardPredicate).firstMatch
        XCTAssertTrue(
            articleCard.waitForExistence(timeout: 15),
            "article card should exist in the feed"
        )
        articleCard.tap()

        // Wait for the article body to confirm the detail loaded.
        let articleBody = app.otherElements.matching(
            NSPredicate(format: "label == 'Article body'")
        ).firstMatch
        XCTAssertTrue(
            articleBody.waitForExistence(timeout: 15),
            "article detail should render before checking for absent recipe chrome"
        )

        // NEGATIVE: Ingredients header must NOT appear on an article detail.
        XCTAssertFalse(
            app.staticTexts["Ingredients"].exists,
            "article detail must NOT show the Ingredients header (CL-63 decision 5)"
        )

        // NEGATIVE: Cook Mode CTA must NOT appear on an article detail.
        XCTAssertFalse(
            app.buttons["recipe.cookMode.cta"].exists,
            "article detail must NOT show the Cook Mode CTA (CL-63 decision 5)"
        )
    }
}

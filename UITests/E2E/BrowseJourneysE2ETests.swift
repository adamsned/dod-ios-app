import XCTest

/// T-610 — comprehensive hermetic browse journeys. Each asserts on the exact
/// canned ``E2EFixtures`` data (three recipes: corn cat 10 "Sides"; lasagna +
/// peach-dump-cake both cat 11 "Mains"). The in-memory store + network stub
/// reset every launch, so these are deterministic with tight timeouts.
///
/// Split from the servings/settings/moderation journeys purely to stay under
/// the SwiftLint `file_length` cap.
@MainActor
final class BrowseJourneysE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Search tab (idle) → tap the "Mains" category row → its filtered recipe
    /// list → open a recipe → detail. Exercises the category-browse surface
    /// with the shared-category fixture (Mains has 2 siblings).
    func test_category_browse_opens_filtered_list_then_detail() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")
        // Let the feed render before switching tabs (categories hydrate on the
        // Search tab's idle appearance).
        XCTAssertTrue(
            app.buttons.matching(identifier: "dod.feed.card").firstMatch.waitForExistence(timeout: 10),
            "feed should load before switching to Search"
        )

        tabBar.buttons["Search"].tap()

        // The idle Search tab lists the fixture categories. Tap "Mains".
        let mains = app.buttons["Mains, 2 recipes"]
        XCTAssertTrue(
            mains.waitForExistence(timeout: 10),
            "the idle Search tab should list the 'Mains' category (2 sibling recipes)"
        )
        mains.tap()

        // Landed on the filtered category list — both Mains recipes present.
        let categoryCards = app.buttons.matching(identifier: "dod.category.card")
        XCTAssertTrue(
            categoryCards.firstMatch.waitForExistence(timeout: 10),
            "the category list should surface the 'Mains' recipe cards"
        )
        XCTAssertTrue(
            app.staticTexts["Dutch Oven Lasagna"].waitForExistence(timeout: 5),
            "the Mains category list should include Dutch Oven Lasagna"
        )

        categoryCards.firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Ingredients"].waitForExistence(timeout: 15),
            "tapping a category recipe card should open recipe detail"
        )
    }

    /// Open a "Mains" recipe (Dutch Oven Lasagna) → scroll to the "Related
    /// recipes" strip → assert its sibling (Peach Dump Cake, same category 11)
    /// renders → tap it → its detail. Pins the shared-category fixture fix that
    /// makes `posts?categories=11` return ≥2.
    ///
    /// The related strip populates on the warm-cache re-open path
    /// (`hydrateCachedRecipe` uses `cached.categoryIDs`, seeded from the feed
    /// list item); a cold first open parses JSON-LD with empty categoryIDs and
    /// shows no strip — real production behavior. So we open, pop, and re-open.
    func test_related_recipes_strip_shows_sibling_and_navigates() {
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        // Feed order is corn(10), lasagna(11), peach(11). Card index 1 is the
        // lasagna (a Mains recipe whose sibling is the peach dump cake).
        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.element(boundBy: 1).waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")

        // Pop back and re-open so the warm-cache path hydrates the related strip.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(feedCards.element(boundBy: 1).waitForExistence(timeout: 10), "feed should return")
        feedCards.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should re-open")

        // Scroll down to the related strip. Its sibling card carries the
        // dod.related.card identifier added for T-610 (a combined a11y element,
        // so query any element type, not just buttons).
        let relatedHeader = app.staticTexts["Related Recipes"]
        let relatedCard = app.descendants(matching: .any)
            .matching(identifier: "dod.related.card").firstMatch
        for _ in 0..<10 where !relatedCard.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            relatedCard.waitForExistence(timeout: 5),
            "the Related recipes strip should render a same-category sibling card"
        )
        XCTAssertTrue(
            relatedHeader.exists,
            "the Related recipes section header should be visible"
        )

        relatedCard.tap()
        XCTAssertTrue(
            app.staticTexts["Ingredients"].waitForExistence(timeout: 15),
            "tapping a related recipe should open its detail"
        )
    }

    /// The WPRM ratings endpoint 403s in the stub. Open a recipe with NO
    /// comments (Dutch Oven Lasagna) → the ratings section degrades to the
    /// "Be the first to rate this recipe." empty state without crashing
    /// (REG-14). The "Ratings & Reviews" header still renders.
    func test_ratings_section_degrades_gracefully_on_forbidden() {
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        // Lasagna (feed card index 1) has no canned comments, so the ratings
        // section shows the "be the first" empty state rather than collapsing.
        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.element(boundBy: 1).waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")

        // Scroll to the ratings section.
        let emptyRatingState = app.staticTexts["Be the first to rate this recipe."]
        for _ in 0..<10 where !emptyRatingState.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            emptyRatingState.waitForExistence(timeout: 5),
            "with the WPRM 403 + no comments, ratings should degrade to the 'be the first' empty state"
        )
        // The app is still alive and responsive (no crash on the 403 path).
        XCTAssertTrue(app.tabBars.firstMatch.exists, "the app should remain responsive after the ratings 403")
    }
}

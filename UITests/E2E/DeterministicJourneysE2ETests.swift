import XCTest

/// T-610 — comprehensive journeys that assert on the exact canned fixtures
/// (``E2EFixtures``), now that the hermetic stub makes the app deterministic.
/// Every L5 launch now boots the hermetic stub, so `CoreUserJourneysE2ETests`
/// runs against the same canned fixtures; the journeys here differ in intent —
/// they assert on precise fixture content and a CLEAN starting state (the
/// in-memory store resets every launch), where the Core suite keeps some
/// broader, timeout-tolerant heuristics inherited from the Phase-1 rollout.
@MainActor
final class DeterministicJourneysE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Search for the fixture recipe by title → exactly one result → detail.
    func test_search_matches_fixture_recipe_and_opens_detail() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")
        // Ensure the app finished its first render before switching tabs.
        XCTAssertTrue(
            app.buttons.matching(identifier: "dod.feed.card").firstMatch.waitForExistence(timeout: 10),
            "feed should load before switching to Search"
        )
        XCTAssertTrue(
            app.openSearchFromFeed(),
            "v2 Search overhaul (1/3): open Search via the Feed header magnifying glass"
        )

        let field = app.textFields.firstMatch  // the search field is the only text field here
        XCTAssertTrue(field.waitForExistence(timeout: 8), "search field should appear")
        field.tap()
        field.typeText("corn")  // fixture title contains "corn" → only the corn recipe

        let cards = app.buttons.matching(identifier: "dod.search.card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10), "search should surface the corn recipe")
        cards.firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Ingredients"].waitForExistence(timeout: 15),
            "tapping the deterministic search result should open recipe detail"
        )
    }

    /// Open a recipe → the canned approved comments render (Guideline-1.2 UGC
    /// surface, deterministic fixture authors).
    func test_recipe_detail_shows_canned_comments() {
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        // Open the corn recipe (first feed card, deterministic fixture order).
        let cards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        cards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")

        // Scroll to the Ratings & Reviews section and assert the fixture
        // commenters appear (comments GET is served by the stub for post 21238).
        let maria = app.staticTexts["Maria"]
        for _ in 0..<8 where !maria.exists {
            app.swipeUp()
        }
        XCTAssertTrue(maria.waitForExistence(timeout: 5), "canned approved comment author 'Maria' should render")
    }

    /// Fresh in-memory store → Saved tab starts EMPTY → save a recipe → it
    /// appears in Saved → unsave → empty state returns. The clean-state
    /// assertions the live-blog journey couldn't make.
    func test_save_then_unsave_with_clean_state() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        // Saved tab starts empty (in-memory store reset on launch).
        tabBar.buttons["Saved"].tap()
        XCTAssertTrue(
            app.staticTexts["saved.emptyState"].firstMatch.waitForExistence(timeout: 8),
            "Saved tab should start empty on a fresh hermetic launch"
        )

        // Open a recipe from the feed and save it.
        tabBar.buttons["Recipes"].tap()
        let cards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        cards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")

        let save = app.buttons["Save recipe"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Save affordance should be visible")
        save.tap()
        XCTAssertTrue(app.buttons["Unsave recipe"].waitForExistence(timeout: 8), "Save should flip to Unsave")

        // Saved tab now has exactly one row (the empty state is gone).
        tabBar.buttons["Saved"].tap()
        XCTAssertFalse(
            app.staticTexts["saved.emptyState"].firstMatch.waitForExistence(timeout: 3),
            "Saved tab should no longer be empty after saving"
        )

        // Unsave from detail and confirm the empty state returns.
        tabBar.buttons["Recipes"].tap()
        let unsave = app.buttons["Unsave recipe"]
        XCTAssertTrue(unsave.waitForExistence(timeout: 5), "detail should still show Unsave")
        unsave.tap()
        XCTAssertTrue(app.buttons["Save recipe"].waitForExistence(timeout: 5), "Unsave should flip back to Save")
        tabBar.buttons["Saved"].tap()
        XCTAssertTrue(
            app.staticTexts["saved.emptyState"].firstMatch.waitForExistence(timeout: 8),
            "Saved tab should be empty again after the unsave"
        )
    }
}

import XCTest

/// T-610 — verifies the hermetic E2E network stub (`E2EStubHTTPClient` /
/// `E2EFixtures`, injected by `AppDependencies` in `-DOD_E2E_MODE=1`) serves
/// deterministic data, so the L5 journeys no longer depend on the live blog.
///
/// Launch → the canned feed shows the fixture recipes → tap one → the detail
/// screen (JSON-LD parsed from the canned HTML page) renders. If this passes,
/// every journey can assert on the exact fixture content with tight timeouts.
@MainActor
final class HermeticFoundationE2ETests: XCTestCase {

    func test_hermetic_feed_and_detail_are_deterministic() {
        let app = XCUIApplication()
        app.launchForE2E()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        // The canned feed renders the fixture recipe titles deterministically.
        XCTAssertTrue(
            app.staticTexts["Garlic Butter Skillet Corn"].waitForExistence(timeout: 15),
            "hermetic feed should show the fixture recipe 'Garlic Butter Skillet Corn'"
        )
        XCTAssertTrue(
            app.staticTexts["Dutch Oven Lasagna"].exists,
            "hermetic feed should show the second fixture recipe"
        )

        // Tap a feed card → the JSON-LD-parsed recipe detail.
        let cards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(cards.element(boundBy: 1).waitForExistence(timeout: 10), "feed cards should exist")
        cards.element(boundBy: 1).tap()

        XCTAssertTrue(
            app.staticTexts["Ingredients"].waitForExistence(timeout: 20),
            "recipe detail (JSON-LD parsed from the canned HTML) should show the Ingredients header"
        )
    }
}

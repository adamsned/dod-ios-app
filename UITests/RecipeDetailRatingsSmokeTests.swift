import XCTest

/// Wave-2 smoke coverage for the comments + ratings integration on
/// `RecipeDetailView`. Read-only: we assert the new section renders, but
/// never POST to dutchovendaddy.com (constitution §3: tests must not
/// write to production blogs).
///
/// Spec trace: US-13 / US-14 / US-15 (CL-21 amendment).
final class RecipeDetailRatingsSmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Mirror SmokeTests setup: skip telemetry + welcome sheet so we
        // land on the feed without manual fiddling.
        app.launchEnvironment["DOD_FORCE_NO_TELEMETRY_APPID"] = "1"
        app.launchEnvironment["DOD_SUPPRESS_ONBOARDING"] = "1"
        // Clean in-memory store per launch (L3 isolation), matching SmokeTests.
        app.launchArguments.append("-DODUseInMemoryStore")
        app.launch()
    }

    /// AC-14.1 + integration assertion: opening a recipe detail must
    /// show the new "Ratings & Reviews" section once the user scrolls
    /// past the related-recipes strip. The section header is a stable
    /// string we can assert without depending on the (network-dependent)
    /// comments themselves.
    func test_recipeDetail_showsRatingsSection_afterRecipeLoads() {
        // Open a real recipe detail from the feed (the helper skips roundup
        // articles that have no Ingredients / Ratings section).
        XCTAssertTrue(
            openRecipeDetailFromFeed(),
            "A feed recipe card should push a recipe detail with an Ingredients section"
        )

        // Scroll to the bottom of the detail screen so the ratings
        // section is in the accessibility tree. A handful of swipes is
        // enough on every recipe in the test fixture set.
        let scrollView = app.scrollViews.firstMatch
        let ratingsHeader = app.staticTexts["Ratings & Reviews"]
        for _ in 0..<8 {
            if ratingsHeader.exists { break }
            scrollView.swipeUp()
        }

        if !ratingsHeader.exists {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "ratings-section-missing"
            shot.lifetime = .keepAlways
            add(shot)

            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "accessibility-hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }

        XCTAssertTrue(
            ratingsHeader.waitForExistence(timeout: 10),
            "Ratings & Reviews header should appear after scrolling to the bottom of the recipe detail"
        )
    }

    /// Opens a real recipe detail from the feed, skipping roundup/article
    /// posts (the feed is "Recipes & Articles" and `RecipeListItem` carries
    /// no kind). Taps `dod.feed.card` cards until one shows "Ingredients".
    /// Mirrors the helper in `SmokeTests`; T-610 fakes are the long-term fix.
    @discardableResult
    private func openRecipeDetailFromFeed(maxCards: Int = 5) -> Bool {
        let cards = app.buttons.matching(identifier: "dod.feed.card")
        guard cards.element(boundBy: 0).waitForExistence(timeout: 20) else { return false }
        for index in 0..<maxCards {
            let card = cards.element(boundBy: index)
            guard card.waitForExistence(timeout: 5) else { return false }
            card.tap()
            if app.staticTexts["Ingredients"].waitForExistence(timeout: 25) {
                return true
            }
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.waitForExistence(timeout: 3) { back.tap() }
            _ = cards.element(boundBy: 0).waitForExistence(timeout: 10)
        }
        return false
    }
}

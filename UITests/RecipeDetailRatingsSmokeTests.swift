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
        app.launch()
    }

    /// AC-14.1 + integration assertion: opening a recipe detail must
    /// show the new "Ratings & Reviews" section once the user scrolls
    /// past the related-recipes strip. The section header is a stable
    /// string we can assert without depending on the (network-dependent)
    /// comments themselves.
    func test_recipeDetail_showsRatingsSection_afterRecipeLoads() {
        // Pick the second recipe row in the feed — the first is often
        // clipped by the nav bar, which makes the tap unreliable
        // (same workaround as `SmokeTests.test_recipeDetailOpensAndShowsContent`).
        let tabLabels: Set<String> = ["Recipes", "Categories", "Search", "Saved"]
        let recipeButtons = app.buttons
            .matching(NSPredicate(format: "NOT (label IN %@)", Array(tabLabels)))
        XCTAssertTrue(
            recipeButtons.element(boundBy: 1).waitForExistence(timeout: 20),
            "Feed should show at least 2 recipe buttons"
        )
        recipeButtons.element(boundBy: 1).tap()

        // Detail screen lands when the Ingredients header is visible.
        let ingredientsHeader = app.staticTexts["Ingredients"]
        XCTAssertTrue(
            ingredientsHeader.waitForExistence(timeout: 45),
            "Recipe detail should show Ingredients section"
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
}

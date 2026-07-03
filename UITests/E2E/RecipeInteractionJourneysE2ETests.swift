import XCTest

/// T-610 — comprehensive hermetic journeys for the recipe-detail interaction
/// surfaces: comment report/block moderation (DUT-501), Cook Mode, and the
/// servings scaler. All assert on the exact ``E2EFixtures`` data; the network
/// stub + moderation store reset every launch.
@MainActor
final class RecipeInteractionJourneysE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Open the corn recipe (post 21238, the only fixture with comments) →
    /// Maria + Diego render → long-press Maria's comment → "Block Maria" →
    /// Maria's comment disappears while Diego's stays (DUT-501 / Guideline 1.2).
    func test_comment_block_hides_only_blocked_author() {
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        // The corn recipe is the first feed card (fixture order).
        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")

        // Scroll to the comments — both canned authors render.
        let maria = app.staticTexts["Maria"]
        let diego = app.staticTexts["Diego"]
        for _ in 0..<10 where !maria.exists {
            app.swipeUp()
        }
        XCTAssertTrue(maria.waitForExistence(timeout: 5), "canned comment author 'Maria' should render")
        XCTAssertTrue(diego.waitForExistence(timeout: 5), "canned comment author 'Diego' should render")

        // Long-press Maria's comment row → context menu → "Block Maria".
        maria.press(forDuration: 1.0)
        let blockMaria = app.buttons["Block Maria"]
        XCTAssertTrue(
            blockMaria.waitForExistence(timeout: 5),
            "the comment context menu should expose a state-aware 'Block Maria' action (DUT-501)"
        )
        blockMaria.tap()

        // Maria's comment is hidden app-wide; Diego's stays visible.
        XCTAssertFalse(
            maria.waitForExistence(timeout: 3),
            "blocking Maria should hide her comment"
        )
        XCTAssertTrue(
            diego.exists,
            "blocking Maria must NOT hide Diego's comment — block is per-author"
        )
    }

    /// Open the corn recipe → long-press Diego's comment → the moderation
    /// context menu exposes both "Report Comment" and "Block Diego"
    /// (DUT-501 Guideline-1.2 required affordances). We assert the menu
    /// composition rather than tapping Report (which opens a mailto: the sim
    /// mail client can't complete deterministically).
    func test_comment_context_menu_exposes_report_and_block() {
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")

        let diego = app.staticTexts["Diego"]
        for _ in 0..<10 where !diego.exists {
            app.swipeUp()
        }
        XCTAssertTrue(diego.waitForExistence(timeout: 5), "canned comment author 'Diego' should render")

        diego.press(forDuration: 1.0)
        XCTAssertTrue(
            app.buttons["Report Comment"].waitForExistence(timeout: 5),
            "the moderation menu must expose 'Report Comment' (Guideline 1.2)"
        )
        XCTAssertTrue(
            app.buttons["Block Diego"].exists,
            "the moderation menu must expose 'Block Diego' (Guideline 1.2)"
        )
    }

    /// Open a recipe → Cook Now → "Step 1 of N" → Next → "Step 2 of N" →
    /// exit → back on detail. Uses the corn recipe (3 fixture steps).
    func test_cook_mode_walks_steps_and_exits() {
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()

        let ingredients = app.staticTexts["Ingredients"]
        XCTAssertTrue(ingredients.waitForExistence(timeout: 15), "detail should open")

        let cookNow = app.buttons["Cook Now"]
        XCTAssertTrue(cookNow.waitForExistence(timeout: 5), "Cook Now CTA should be visible")
        cookNow.tap()

        let stepOne = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Step 1 of'")).firstMatch
        XCTAssertTrue(stepOne.waitForExistence(timeout: 5), "Cook Mode should render 'Step 1 of N' on entry")

        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 3), "the corn recipe has 3 steps so 'Next' should exist")
        next.tap()
        let stepTwo = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Step 2 of'")).firstMatch
        XCTAssertTrue(stepTwo.waitForExistence(timeout: 8), "Cook Mode should advance to 'Step 2 of N'")

        let exit = app.buttons["Exit Cook Mode"]
        XCTAssertTrue(exit.waitForExistence(timeout: 3), "Exit Cook Mode button should be present")
        exit.tap()
        XCTAssertTrue(ingredients.waitForExistence(timeout: 5), "after exiting Cook Mode, detail should re-render")
    }

    /// Open a recipe → the servings scaler shows "Serves 4" → tap the
    /// stepper's increment → "Serves 8" (or higher) renders and a scaled
    /// ingredient quantity changes (US-31). Uses the corn recipe
    /// ("4 servings", "4 cups corn kernels").
    func test_servings_scaler_scales_ingredient_quantity() {
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")

        // The scaler starts at the recipe yield (4 servings).
        let servesFour = app.staticTexts["Serves 4"]
        for _ in 0..<8 where !servesFour.exists {
            app.swipeUp()
        }
        XCTAssertTrue(servesFour.waitForExistence(timeout: 5), "the servings scaler should start at 'Serves 4'")
        // The unscaled ingredient quantity is present.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '4 cups corn'")).firstMatch.exists,
            "the unscaled ingredient '4 cups corn kernels' should render at 4 servings"
        )

        // The Stepper exposes an Increment button under the "Servings" element.
        let stepper = app.steppers.firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 5), "a servings stepper should exist")
        let increment = stepper.buttons.element(boundBy: 1)
        XCTAssertTrue(increment.waitForExistence(timeout: 3), "the stepper should expose an increment button")
        // Scale up to 8 servings (4 taps → doubles the corn to 8 cups).
        for _ in 0..<4 {
            increment.tap()
        }

        XCTAssertTrue(
            app.staticTexts["Serves 8"].waitForExistence(timeout: 5),
            "scaling up 4 steps should read 'Serves 8'"
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '8 cups corn'")).firstMatch
                .waitForExistence(timeout: 5),
            "doubling servings should scale '4 cups corn kernels' to '8 cups corn kernels'"
        )
    }
}

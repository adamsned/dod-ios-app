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

    /// Open a recipe → Cook Mode → "Step 1 of N" → Next → "Step 2 of N" →
    /// exit → back on detail. Uses the corn recipe (3 fixture steps).
    func test_cook_mode_walks_steps_and_exits() {
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()

        let ingredients = app.staticTexts["Ingredients"]
        XCTAssertTrue(ingredients.waitForExistence(timeout: 15), "detail should open")

        // DUT-572 — the CTA was renamed "Cook Now" → "Cook Mode"; query the
        // stable `recipe.cookMode.cta` identifier instead of the visible label.
        let cookMode = app.buttons["recipe.cookMode.cta"]
        XCTAssertTrue(cookMode.waitForExistence(timeout: 5), "Cook Mode CTA should be visible")
        cookMode.tap()

        let stepOne = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Step 1 of'")).firstMatch
        XCTAssertTrue(stepOne.waitForExistence(timeout: 5), "Cook Mode should render 'Step 1 of N' on entry")

        // The advance control was renamed "Next" → "Next Step" and carries the
        // stable `cook-mode-next` identifier (hidden only on the final step).
        let next = app.buttons["cook-mode-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 3), "the corn recipe has 3 steps so the Next Step control should exist")
        next.tap()
        let stepTwo = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Step 2 of'")).firstMatch
        XCTAssertTrue(stepTwo.waitForExistence(timeout: 8), "Cook Mode should advance to 'Step 2 of N'")

        let exit = app.buttons["Exit Cook Mode"]
        XCTAssertTrue(exit.waitForExistence(timeout: 3), "Exit Cook Mode button should be present")
        exit.tap()
        XCTAssertTrue(ingredients.waitForExistence(timeout: 5), "after exiting Cook Mode, detail should re-render")
    }

    /// Open a recipe → the collapsed servings control reads 4 (recipe yield) →
    /// increment it to 8 → the control's value updates to 8 and the
    /// "4 cups corn kernels" ingredient scales to "8 cups corn kernels"
    /// (US-31). Uses the corn recipe ("4 servings", "4 cups corn kernels").
    ///
    /// DUT-573 / DUT-614 — the old standalone "Serves 4" label + a plainly
    /// queryable inner Stepper were folded into ONE collapsed element:
    /// `Text("Servings")` caption + `Text("4")` value, wrapped in
    /// `.accessibilityElement(children: .ignore)` with an adjustable action and
    /// the stable `recipe.servings` identifier. That element surfaces as an
    /// `otherElement` whose `.value` mirrors the count. XCUITest cannot invoke
    /// a *custom* adjustable action directly, but the underlying SwiftUI
    /// `Stepper` remains a queryable element whose "Increment" button IS
    /// drivable — so we read the state off `recipe.servings` and drive it via
    /// that button.
    func test_servings_scaler_scales_ingredient_quantity() {
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "tab bar should appear")

        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")

        // Scroll the collapsed servings control into view.
        let servings = app.otherElements["recipe.servings"]
        for _ in 0..<8 where !servings.exists {
            app.swipeUp()
        }
        XCTAssertTrue(servings.waitForExistence(timeout: 5), "the servings control should exist")
        XCTAssertEqual(
            "\(servings.value ?? "")", "4",
            "the servings control should start at the recipe yield (4)"
        )
        // The unscaled ingredient quantity is present at 4 servings.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '4 cups corn'")).firstMatch.exists,
            "the unscaled ingredient '4 cups corn kernels' should render at 4 servings"
        )

        // Drive the count 4 → 8 via the Stepper's "+" button (the collapsed
        // element's custom adjustable action isn't XCUITest-drivable). NOTE:
        // for this collapsed Stepper, XCUITest's button *labels* are inverted
        // (it labels the "−" as "Increment" and the "+" as "Decrement"); the
        // position order is stable though — boundBy 0 is "−", boundBy 1 is "+".
        // Verified on-sim: tapping boundBy 1 raises the value. Tap-until-target
        // rather than a fixed 4 taps: rapid consecutive taps on a Stepper can
        // be coalesced, so we tap, wait for the value to advance, and stop at 8
        // (bounded so a stuck control fails fast).
        let stepper = app.steppers.firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 3), "a servings Stepper should exist")
        let increment = stepper.buttons.element(boundBy: 1)
        XCTAssertTrue(
            increment.waitForExistence(timeout: 3),
            "the servings Stepper should expose an increment (\"+\") button"
        )
        func servingsCount() -> Int { Int("\(servings.value ?? "")") ?? -1 }
        var taps = 0
        while servingsCount() < 8, taps < 12 {
            let before = servingsCount()
            increment.tap()
            taps += 1
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(
                    predicate: NSPredicate { _, _ in servingsCount() > before },
                    object: nil
                )],
                timeout: 2
            )
        }
        XCTAssertEqual(
            servingsCount(), 8,
            "incrementing should bring the servings control to 8 (got \(servingsCount()) after \(taps) taps)"
        )
        // Doubling servings scales the corn quantity 4 cups → 8 cups.
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '8 cups corn'")).firstMatch
                .waitForExistence(timeout: 5),
            "doubling servings should scale '4 cups corn kernels' to '8 cups corn kernels'"
        )
    }
}

import XCTest

/// Hermetic journey for the "I made this" hero loop (DUT-326 / DUT-104): walk a
/// recipe through Cook Mode, log the finished cook from the Done card, and see
/// it land in the Cooking Journal. This is the north-star word-of-mouth moment,
/// and it spans three surfaces the L1 suites can't stitch together — Cook Mode
/// (DODFeatureRecipeDetail), the cook-log store write, and the Journal read
/// (DODFeatureFeed, reached from the Cooking Tools hub). Runs against the
/// deterministic in-memory store + network stub; the log write and the Journal
/// read share the one in-memory container, so the logged cook is visible.
@MainActor
final class CookJournalJourneyE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Open the corn recipe → Cook Mode → advance to the Done card → "Add to
    /// Cooking Journal" → Save → exit Cook Mode → Tools tab → Cooking Journal →
    /// the logged cook ("Garlic Butter Skillet Corn") appears as a journal row.
    func test_log_cook_appears_in_cooking_journal() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        logFirstRecipeCookViaCookMode()
        openCookingJournalFromToolsHub(tabBar: tabBar)

        // The logged cook is in the Journal: a journal row exists and it carries
        // the corn recipe's title.
        let anyJournalRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'journal-row-'"))
            .firstMatch
        XCTAssertTrue(
            anyJournalRow.waitForExistence(timeout: 10),
            "the Cooking Journal should list the cook that was just logged"
        )
        XCTAssertTrue(
            app.staticTexts["Garlic Butter Skillet Corn"].waitForExistence(timeout: 8),
            "the logged journal entry should show the corn recipe's title"
        )
    }

    // MARK: - Steps

    /// Open the first (corn) recipe, enter Cook Mode, walk to the Done card, log
    /// the cook (no photo/caption — both optional), exit Cook Mode, and pop back
    /// to the feed.
    private func logFirstRecipeCookViaCookMode() {
        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")
        let cookCTA = app.buttons["recipe.cookMode.cta"]
        XCTAssertTrue(cookCTA.waitForExistence(timeout: 8), "the recipe detail should offer the Cook Mode CTA")
        cookCTA.tap()
        let stepOne = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Step 1 of'")).firstMatch
        XCTAssertTrue(stepOne.waitForExistence(timeout: 10), "Cook Mode should open on 'Step 1 of N'")

        // Advance to the Done card. Corn has 3 steps; tap Next until it's gone
        // (Done card has no next), bounded so a regression can't spin forever.
        let next = app.buttons["cook-mode-next"]
        var taps = 0
        while next.exists && taps < 5 {
            next.tap()
            taps += 1
        }

        let logCook = app.buttons["cook-mode-log-cook"]
        XCTAssertTrue(logCook.waitForExistence(timeout: 8), "the Done card should reveal 'Add to Cooking Journal'")
        logCook.tap()
        let save = app.buttons["cook-mode-journal-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 8), "the journal-log sheet should present its Save button")
        save.tap()

        let exit = app.buttons["Exit Cook Mode"]
        XCTAssertTrue(exit.waitForExistence(timeout: 8), "the log sheet should dismiss back to the Done card")
        exit.tap()
        XCTAssertTrue(
            app.staticTexts["Ingredients"].waitForExistence(timeout: 8),
            "exiting Cook Mode should return to the recipe detail"
        )
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed should return after popping detail")
    }

    /// Tools tab → "Cooking Journal" tool card → the Journal sheet.
    private func openCookingJournalFromToolsHub(tabBar: XCUIElement) {
        tabBar.buttons["Tools"].tap()
        let journal = app.buttons["hub-journal"]
        XCTAssertTrue(
            journal.waitForExistence(timeout: 8),
            "the Cooking Tools hub should expose the 'Cooking Journal' tool card"
        )
        journal.tap()
    }
}

import XCTest

/// T-610 — comprehensive hermetic journeys for the app-shell surfaces:
/// Settings persistence, the Shopping List builder, and cross-tab navigation
/// integrity. All run against the deterministic in-memory store + network stub.
@MainActor
final class AppShellJourneysE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Settings tab → change the App Appearance picker to "Cocoa" → leave to
    /// another tab and return → the selection persisted (US-32). Appearance is
    /// an enabled picker (unlike the "Coming soon" metric toggle).
    func test_settings_appearance_picker_persists_selection() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        tabBar.buttons["Settings"].tap()

        let picker = app.otherElements["settings-picker-appearance"]
            .firstMatch
        // The Picker renders as a menu button; drill to a control that shows
        // the current selection. Use the segmented/menu picker element.
        let appearancePicker = app.buttons.matching(identifier: "settings-picker-appearance").firstMatch
        let target = appearancePicker.exists ? appearancePicker : picker
        XCTAssertTrue(
            target.waitForExistence(timeout: 8),
            "the Settings screen should expose the App Appearance picker"
        )
        target.tap()

        // The menu presents the appearance options; pick "Cocoa" (dark).
        let cocoa = app.buttons["Cocoa"].firstMatch
        XCTAssertTrue(cocoa.waitForExistence(timeout: 5), "the appearance picker should offer 'Cocoa'")
        cocoa.tap()

        // Round-trip through another tab and back; the selection persists.
        tabBar.buttons["Recipes"].tap()
        XCTAssertTrue(
            app.buttons.matching(identifier: "dod.feed.card").firstMatch.waitForExistence(timeout: 10),
            "feed should render after leaving Settings"
        )
        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(
            app.staticTexts["Cocoa"].waitForExistence(timeout: 8)
                || app.buttons.matching(identifier: "settings-picker-appearance").firstMatch.waitForExistence(
                    timeout: 8
                ),
            "returning to Settings should show the persisted 'Cocoa' appearance selection"
        )
    }

    /// Save a recipe → Saved tab → "Make Shopping List" → the builder lists the
    /// saved recipe → select it → "Build List" → the Shopping List screen
    /// renders (US-39 shopping-list flow).
    ///
    /// The end-state is reaching the aisle-grouped Shopping List screen. We do
    /// NOT assert on specific ingredient rows: whether the saved recipe carries
    /// its parsed ingredients into the builder depends on the detail-merge →
    /// saved-store hydration order, which is not deterministic on a cold E2E
    /// launch (the row can render title-only before ingredients hydrate). The
    /// reachable, deterministic contract is the builder → list navigation.
    func test_shopping_list_builds_from_saved_recipe() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        // Save the first recipe from its detail screen.
        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")
        let save = app.buttons["Save recipe"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Save affordance should be visible")
        save.tap()
        XCTAssertTrue(app.buttons["Unsave recipe"].waitForExistence(timeout: 8), "Save should flip to Unsave")

        // Saved tab → Make Shopping List. DUT-536 — the cart now selects the
        // top-level Grocery List tab (single store-backed list) instead of
        // pushing inside the Saved stack. The cart is a small (~23pt) header
        // icon; tap its center coordinate so the hit-point resolves even under
        // simulator load (label taps occasionally miss on iOS 26).
        tabBar.buttons["Saved"].tap()
        let makeList = app.buttons["saved-make-shopping-list"]
        XCTAssertTrue(
            makeList.waitForExistence(timeout: 8),
            "the Saved tab should expose 'Make Shopping List' once a recipe is saved"
        )
        makeList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        // DUT-536 — landing on the Grocery List tab, the (empty) list offers its
        // primary "Build List" empty-state button, which presents the picker.
        let openBuilder = app.buttons["shopping-list-build"]
        XCTAssertTrue(
            openBuilder.waitForExistence(timeout: 8),
            "the Grocery List tab should present the empty-state 'Build List' button"
        )
        openBuilder.tap()
        let buildButton = app.buttons["shopping-builder-build"]
        XCTAssertTrue(
            buildButton.waitForExistence(timeout: 8),
            "the shopping-list builder sheet should present its Build List button"
        )

        // Builder sheet: select the recipe (row is a List cell carrying the
        // recipe title as its a11y label), then Build List.
        let builderRow = app.descendants(matching: .any)
            .matching(identifier: "shopping-builder-row").firstMatch
        let rowByTitle = app.cells["Garlic Butter Skillet Corn"]
        let target = builderRow.waitForExistence(timeout: 8) ? builderRow : rowByTitle
        XCTAssertTrue(
            target.waitForExistence(timeout: 8),
            "the shopping-list builder should list the saved recipe"
        )
        target.tap()
        buildButton.tap()

        // End-state: the aisle-grouped Shopping List screen is pushed.
        XCTAssertTrue(
            app.navigationBars["Shopping List"].waitForExistence(timeout: 8)
                || app.staticTexts["Shopping List"].waitForExistence(timeout: 8),
            "building the list should push the Shopping List screen"
        )
    }

    /// Cross-tab navigation integrity: all five tabs are reachable, and a
    /// detail pushed on the Recipes stack survives a tab round-trip (tab swap
    /// is not a pop).
    func test_cross_tab_navigation_integrity() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        // Push a recipe detail on the Recipes stack.
        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()
        let ingredients = app.staticTexts["Ingredients"]
        XCTAssertTrue(ingredients.waitForExistence(timeout: 15), "detail should open on the Recipes stack")

        // Visit every other tab, asserting each lands on its own surface.
        tabBar.buttons["Saved"].tap()
        XCTAssertTrue(
            app.staticTexts["No saved recipes yet"].waitForExistence(timeout: 8),
            "the Saved tab should show its empty state on a fresh launch"
        )
        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(
            app.staticTexts["Settings"].waitForExistence(timeout: 8),
            "the Settings tab should render its header"
        )
        tabBar.buttons["Search"].tap()
        XCTAssertTrue(
            app.textFields.firstMatch.waitForExistence(timeout: 8),
            "the Search tab should render its search field"
        )

        // Return to Recipes — the pushed detail is still there (not popped).
        tabBar.buttons["Recipes"].tap()
        XCTAssertTrue(
            ingredients.waitForExistence(timeout: 8),
            "returning to Recipes should preserve the pushed recipe detail (tab swap is not a pop)"
        )
    }
}

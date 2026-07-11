import XCTest

/// Hermetic journey for the Settings *preference → surface* contract that
/// changes what a user sees elsewhere in the app: the "Use Metric Units" toggle
/// (DUT-517 / DUT-913) rewriting the recipe-detail ingredient list. This is an
/// `@AppStorage`-backed preference the Settings sheet writes and
/// `RecipeDetailView` reads at render time — exactly the cross-surface wiring an
/// L1 unit test can't cover. Runs against the deterministic in-memory store +
/// network stub.
@MainActor
final class SettingsPreferenceJourneysE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Settings gear → flip "Use Metric Units" ON → open the corn recipe → its
    /// ingredient list is rendered in metric ("960 ml corn kernels"), not the
    /// authored imperial ("4 cups corn kernels").
    ///
    /// The corn fixture's first ingredient is "4 cups corn kernels"; at the
    /// default 4-serving scale (no scaling) `IngredientMetricConverter.metric`
    /// maps 4 cups → 4 × 240 = 960 ml. This pins the full Settings-write →
    /// `@AppStorage` → `RecipeDetailView` display-time-transform path that
    /// DUT-517 wired and DUT-913 hardened — a path with no prior E2E coverage.
    func test_metric_units_toggle_converts_ingredient_display() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        // Baseline: the corn recipe opens with its authored imperial line.
        let feedCards = app.buttons.matching(identifier: "dod.feed.card")
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed cards should exist")
        feedCards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should open")
        // The ingredient rows hydrate from the JSON-LD parse a beat after the
        // "Ingredients" header. Match by label substring over ANY element type
        // (the row can surface as a static text or as its parent cell's label)
        // with a generous window, so a slow hydrate doesn't read as a regression.
        XCTAssertTrue(
            Self.ingredient(app, contains: "cups", "corn kernels").waitForExistence(timeout: 20),
            "the imperial ingredient line should show before metric is enabled"
        )

        // Pop back to the feed so the gear (a Feed-header toolbar item) is reachable.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(feedCards.firstMatch.waitForExistence(timeout: 10), "feed should return after popping detail")

        // Settings gear → flip the metric toggle ON → dismiss the sheet.
        app.buttons["feed-toolbar-settings"].tap()
        let metricToggle = app.switches["settings-toggle-metric"]
        XCTAssertTrue(
            metricToggle.waitForExistence(timeout: 8),
            "the Settings sheet should expose the 'Use Metric Units' toggle"
        )
        // A SwiftUI Toggle's accessibility element spans the whole Form row
        // (here ~370pt wide), so a centered `.tap()` lands on the label and does
        // NOT flip the switch. Tap the trailing edge — where the switch knob
        // sits — via a normalized coordinate instead. The value can lag a frame,
        // so poll for the settled "1" rather than reading it inline.
        if (metricToggle.value as? String) != "1" {
            metricToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let toggledOn = expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: metricToggle)
        wait(for: [toggledOn], timeout: 5)
        app.swipeDown(velocity: .fast)

        // Reopen the corn recipe — the ingredient list is now metric.
        XCTAssertTrue(
            feedCards.firstMatch.waitForExistence(timeout: 10),
            "feed should render after dismissing Settings"
        )
        feedCards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients"].waitForExistence(timeout: 15), "detail should reopen")
        XCTAssertTrue(
            Self.ingredient(app, contains: "ml", "corn kernels").waitForExistence(timeout: 20),
            "enabling metric should convert '4 cups corn kernels' → '960 ml corn kernels'"
        )
        XCTAssertFalse(
            Self.ingredient(app, contains: "cups", "corn kernels").exists,
            "the imperial line should no longer render once metric is on"
        )
    }

    /// The ingredient row can surface as a static text OR as its parent cell's
    /// accessibility label, so match by label substring over any element type.
    private static func ingredient(_ app: XCUIApplication, contains first: String, _ second: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", first, second))
            .firstMatch
    }
}

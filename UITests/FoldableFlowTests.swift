import XCTest

/// DUT-2352 — foldable (iPhone Duo) UI flow. autodev's foldable check runs this
/// class on a private iPhone Duo simulator. The unfolded Duo can show the
/// iPad-style sidebar instead of the bottom tab bar, so every helper here
/// detects the layout from the live UI rather than the device idiom.
final class FoldableFlowTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["DOD_FORCE_NO_TELEMETRY_APPID"] = "1"
        app.launchEnvironment["DOD_SUPPRESS_ONBOARDING"] = "1"
        app.launchArguments.append("-DODUseInMemoryStore")
        app.launch()
    }

    // MARK: - Layout-agnostic navigation

    /// True when the bottom tab bar is showing (folded / phone layout).
    private var hasTabBar: Bool { app.tabBars.firstMatch.exists }

    /// Wait until the first screen is interactive on either layout (same probe
    /// as `SmokeTests.waitForAppReady`).
    @discardableResult
    private func waitForAppReady(timeout: TimeInterval = 12) -> Bool {
        func settingsVisible() -> Bool {
            app.buttons["feed-toolbar-settings"].exists
                || app.buttons["sidebar-settings-row"].exists
                || app.buttons["Settings"].exists
                || app.cells["Settings"].exists
                || app.staticTexts["Settings"].exists
        }
        let deadline = Date().addingTimeInterval(timeout)
        while !settingsVisible() && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
        }
        return settingsVisible()
    }

    /// Navigate to a top-level tab via the bottom tab bar when present, else
    /// via the sidebar row (button / cell / static text).
    private func goToTab(phoneLabel: String, padTitle: String) {
        if hasTabBar {
            app.tabBars.firstMatch.buttons[phoneLabel].tap()
            return
        }
        for element in [app.buttons[padTitle], app.cells[padTitle], app.staticTexts[padTitle]] {
            if element.firstMatch.waitForExistence(timeout: 6) {
                element.firstMatch.tap()
                return
            }
        }
        XCTFail("Could not find sidebar row '\(padTitle)'")
    }

    /// Open the Settings sheet: Feed header gear on the tab-bar layout, the
    /// sidebar Settings row otherwise.
    private func openSettings() {
        let identifier = hasTabBar ? "feed-toolbar-settings" : "sidebar-settings-row"
        let control = app.buttons[identifier]
        if control.waitForExistence(timeout: 6) {
            control.tap()
        } else {
            XCTFail("Could not find the Settings control '\(identifier)'")
        }
    }

    // MARK: - Tests

    func testMainDestinationsRenderOnFoldable() {
        XCTAssertTrue(waitForAppReady(timeout: 20), "App should be ready within 20 s")

        // Recipes (Feed) — default destination; header search button is the main element.
        goToTab(phoneLabel: "Recipes", padTitle: "Recipes & Articles")
        XCTAssertTrue(
            app.buttons["feed-open-search"].waitForExistence(timeout: 8),
            "Recipes should render its header search button"
        )

        // Saved — fresh in-memory store, so the empty state is the main element.
        goToTab(phoneLabel: "Saved", padTitle: "Saved")
        XCTAssertTrue(
            app.staticTexts["saved.emptyState"].firstMatch.waitForExistence(timeout: 6),
            "Saved should render its empty state"
        )

        // Tools — Cooking Tools hub keystone row.
        goToTab(phoneLabel: "Tools", padTitle: "Cooking Tools")
        XCTAssertTrue(
            app.buttons["hub-first-cookout"].waitForExistence(timeout: 8),
            "Cooking Tools hub should render its first row"
        )
    }
}
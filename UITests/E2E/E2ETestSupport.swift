import XCTest

/// Shared launch-helper for the L5 end-to-end user-journey suite.
///
/// The L5 target (`DODAppE2ETests`) is XCUITest, identical framework to L3
/// (`DODAppUITests`), but lives in its own scheme so CI can run it
/// label-gated rather than every PR (constitution §6, AC-T5, CL-58).
///
/// Every E2E test launches the host via `XCUIApplication().launchForE2E()`,
/// which sets:
///
/// - `-DOD_E2E_MODE=1` (launch arg) + `DOD_E2E_MODE=1` (env) — read by
///   `App/DODApp.swift` `applyTestLaunchOverrides()` and stashed into
///   `DODEnvironment.isE2EMode`. T-610 wired the always-on hermetic path: in
///   this mode the host swaps in `FakeAppDependencies` + `E2EStubHTTPClient`,
///   which serve the canned `E2EFixtures`, so the whole suite runs
///   deterministically against the real code paths with NO live-blog
///   dependency. (The original Phase-1 rollout, T-602, only recorded the flag
///   and drove the live blog; that era is over.)
/// - `DOD_FORCE_NO_TELEMETRY_APPID=1` (env) — REG-1 regression guard; same
///   shape `UITests/SmokeTests.swift` uses.
/// - `DOD_SUPPRESS_ONBOARDING=1` (env, default) — boots straight into the
///   tab bar. Tests that want the welcome sheet (e.g. the first-launch
///   onboarding journey) opt out by passing `suppressOnboarding: false`,
///   which removes the env var and appends `-DODForceFreshOnboarding` so
///   the welcome sheet is guaranteed to appear.
///
/// Adding a sixth journey: launch via `launchForE2E()`, assert a meaningful
/// end-state condition, keep the wall-clock under 30s. Future journeys may
/// pass additional `launchArguments` (e.g. `["-DODOpenURL",
/// "dod://recipe/<id>"]` for the widget-deep-link journey).
enum E2ETestSupport {

    /// The full set of names visible on the bottom tab bar. Used to filter
    /// `app.buttons` to recipe-row buttons only (which share the same query
    /// collection — XCUITest doesn't distinguish a tab-bar `Button` from a
    /// recipe-card `Button` natively). Order tracks `AppTab.allCases` per
    /// AC-16.6; if that order shifts, the L3 smoke `test_tabBarOrderMatchesSpec`
    /// blocks it before we get here.
    /// T-912 / DUT-551 (CL-306) — the Grocery List + Settings tabs retired (the
    /// Shopping List folded into the Cooking Tools hub, whose bottom-tab label is
    /// "Tools"; Settings moved to a header gear). v2 Search overhaul (1/3) retired
    /// the Search tab too (Search now pushes within the Feed stack). Three tabs now.
    static let tabLabels: Set<String> = ["Recipes", "Saved", "Tools"]
}

extension XCUIApplication {

    /// Launch the host into L5 E2E mode with the standard set of overrides
    /// every journey needs.
    ///
    /// - Parameters:
    ///   - suppressOnboarding: `true` (default) boots the app past the
    ///     welcome sheet into the tab bar. Set to `false` for the
    ///     first-launch journey that needs to assert the welcome flow.
    ///   - extraLaunchArguments: appended after the standard `-DOD_E2E_MODE=1`
    ///     and onboarding flags. Used by the widget-deep-link journey to
    ///     pass `["-DODOpenURL", "dod://recipe/<id>"]`.
    func launchForE2E(
        suppressOnboarding: Bool = true,
        extraLaunchArguments: [String] = []
    ) {
        // L5 mode flag. Read by `App/DODApp.swift` `applyTestLaunchOverrides()`
        // and stashed into `DODEnvironment.isE2EMode`.
        launchArguments.append("-DOD_E2E_MODE=1")
        launchEnvironment["DOD_E2E_MODE"] = "1"

        // REG-1 regression guard — no telemetry app id means no SDK
        // pre-init crash on first `.appOpen` signal. Same shape `SmokeTests`
        // uses.
        launchEnvironment["DOD_FORCE_NO_TELEMETRY_APPID"] = "1"

        if suppressOnboarding {
            launchEnvironment["DOD_SUPPRESS_ONBOARDING"] = "1"
        } else {
            // Belt + suspenders: drop the suppress flag (if any other layer
            // sets it) AND force the onboarding flag to reset so the welcome
            // sheet appears on launch. `-DODForceFreshOnboarding` is the
            // escape hatch `App/DODApp.swift` documents for the same case.
            launchEnvironment.removeValue(forKey: "DOD_SUPPRESS_ONBOARDING")
            launchArguments.append("-DODForceFreshOnboarding")
        }

        launchArguments.append(contentsOf: extraLaunchArguments)
        launch()
    }

    /// v2 Search overhaul (1/3) — open the Search screen the way a user now does:
    /// Search is no longer a bottom tab. It's PUSHED within the Feed tab's stack
    /// via the header's magnifying-glass button (`feed-open-search`). This helper
    /// re-selects the Recipes tab (idempotent; re-tapping the selected tab pops
    /// its stack to root) and taps that button, so any journey that used to do
    /// `tabBar.buttons["Search"].tap()` can call `app.openSearchFromFeed()`
    /// instead. Waits for the pushed SearchView's "Search Recipes" field so the
    /// caller can act immediately.
    @discardableResult
    func openSearchFromFeed(timeout: TimeInterval = 10) -> Bool {
        let tabBar = tabBars.firstMatch
        if tabBar.buttons["Recipes"].exists {
            tabBar.buttons["Recipes"].tap()
        }
        let openSearch = buttons["feed-open-search"]
        guard openSearch.waitForExistence(timeout: timeout) else { return false }
        openSearch.tap()
        return textFields["Search Recipes"].waitForExistence(timeout: timeout)
    }
}

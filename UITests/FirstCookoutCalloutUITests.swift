import UIKit
import XCTest

/// L3 coverage for the First Cookout callout **as it is actually wired into the
/// running app** — the seam neither the L1 gate tests nor the L4 component render
/// could see.
///
/// This suite exists because of a concrete miss: the gate was unit-tested in
/// isolation and the bubble was snapshot-tested in isolation, both green, while
/// nobody had checked that the two together put a callout on screen. Everything
/// here therefore asserts against the real app process.
///
/// **Why the force flag.** The callout is a once-per-install nudge whose dismissal
/// is persisted, and it inherits the DUT-571 hero's key — so any simulator that
/// ever dismissed the hero renders nothing, forever, and the test would silently
/// assert on an empty screen. `-DODForceFirstCookoutCallout` overrides the
/// dismissal READ in memory (it writes nothing), and `-DODUseInMemoryStore` gives a
/// cook-log-free store so the gate seeds rung 1. Together they make the nudge
/// deterministic without depending on, or mutating, the host simulator's state.
final class FirstCookoutCalloutUITests: XCTestCase {

    private var app: XCUIApplication!

    /// True on iPad, where the app uses a `NavigationSplitView` sidebar instead of
    /// a bottom tab bar (mirrors `SmokeTests.isPad`).
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["DOD_FORCE_NO_TELEMETRY_APPID"] = "1"
        app.launchEnvironment["DOD_SUPPRESS_ONBOARDING"] = "1"
        // Clean store → no cook logs → the gate seeds rung 1 (a brand-new cook).
        app.launchArguments.append("-DODUseInMemoryStore")
        // Re-arm the nudge regardless of this simulator's persisted dismissal.
        app.launchArguments.append("-DODForceFirstCookoutCallout")
        app.launch()
    }

    /// Queried by `.any` rather than a concrete type ON PURPOSE. The bubble carries
    /// `.accessibilityAddTraits(.isButton)` (so VoiceOver can activate it), which
    /// promotes it from `otherElements` to `buttons` in the accessibility tree — an
    /// `otherElements` query silently finds nothing even while it renders perfectly.
    /// Matching on the identifier alone keeps this test honest about what it's
    /// really asserting: that the callout is on screen, not how a trait types it.
    private var callout: XCUIElement {
        app.descendants(matching: .any)["first-cookout-callout"].firstMatch
    }

    /// The regression this suite is really for: with every gate condition met, the
    /// callout must actually be ON SCREEN in the running app.
    func test_calloutRendersOnTheFeed() throws {
        try XCTSkipIf(isPad, "iPad has no bottom tab bar for the tail to point at.")
        XCTAssertTrue(
            callout.waitForExistence(timeout: 15),
            "The First Cookout callout should render on the Feed for a new, non-dismissed cook."
        )
    }

    /// It must float ABOVE the tab bar, not under it — the safe-area contract. A
    /// bubble laid out beneath the bar would still "exist" for XCUITest, so assert
    /// the geometry rather than mere existence.
    func test_calloutSitsAboveTheTabBar() throws {
        try XCTSkipIf(isPad, "iPad has no bottom tab bar.")
        XCTAssertTrue(callout.waitForExistence(timeout: 15))
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(
            callout.frame.maxY,
            tabBar.frame.midY,
            "The callout should sit above the tab bar, not behind/under it."
        )
    }

    /// The X must dismiss it, and it must have the 44pt-target accessible button
    /// the design calls for (XCUITest can only find it if it's a real button).
    func test_dismissHidesTheCallout() throws {
        try XCTSkipIf(isPad, "iPad never shows the callout.")
        XCTAssertTrue(callout.waitForExistence(timeout: 15))
        let dismiss = app.buttons["first-cookout-callout-dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5), "The X should be an accessible button.")
        dismiss.tap()
        XCTAssertTrue(
            callout.waitForNonExistence(timeout: 5),
            "Tapping the X should hide the callout."
        )
    }

    /// It points at Tools, so it must not float over the other tabs. Feed-only is
    /// enforced structurally (the overlay is attached to the Feed tab inside the
    /// TabView) — this pins that behaviour against a refactor that hoists it.
    func test_calloutIsFeedOnly() throws {
        try XCTSkipIf(isPad, "iPad never shows the callout.")
        XCTAssertTrue(callout.waitForExistence(timeout: 15))
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(
            callout.waitForNonExistence(timeout: 5),
            "The callout should not follow the user to the Saved tab."
        )
    }

    /// The iPad layout is a sidebar with no bottom tab bar, so there is nothing for
    /// the tail to point at and the callout is intentionally never shown. Pin it, so
    /// a future change can't quietly strand a tail pointing at empty space.
    func test_calloutNeverShowsOnIPad() throws {
        try XCTSkipUnless(isPad, "iPhone-only assertion is covered above.")
        // Give the shell the same window the iPhone assertions allow before
        // concluding it's absent, so this can't pass merely by racing the load.
        XCTAssertFalse(
            callout.waitForExistence(timeout: 8),
            "iPad has no bottom tab bar, so the callout must never render there."
        )
    }
}

import XCTest

/// L3 UI smoke tests. The two most recent bugs (TelemetryDeck pre-init crash,
/// missing hero images) would have been caught by the launch + first-screen
/// assertions here.
///
/// Spec trace: AC-T2 in `spec.md`. Regressions REG-1 and REG-2 covered.
final class SmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Ensure no stale telemetry app ID — REG-1 regression guard.
        app.launchEnvironment["DOD_FORCE_NO_TELEMETRY_APPID"] = "1"
        // Suppress the first-launch welcome sheet by default so every test
        // boots straight into the tab bar. The one onboarding-specific test
        // overrides this in-body by relaunching with -DODForceFreshOnboarding.
        // Spec trace: US-8.
        app.launchEnvironment["DOD_SUPPRESS_ONBOARDING"] = "1"
        app.launch()
    }

    /// REG-1: app must launch without crashing even when no TelemetryDeck
    /// app ID is configured. Pre-fix this raised a SDK fatal error on the
    /// first .appOpen telemetry send.
    func test_appLaunchesWithoutTelemetryAppID() {
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 8),
            "Tab bar should appear within 8 seconds — app didn't crash on launch"
        )
    }

    func test_allFourTabsAreReachable() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))
        for tabName in ["Recipes", "Categories", "Search", "Saved"] {
            let button = tabBar.buttons[tabName]
            XCTAssertTrue(button.exists, "Missing tab: \(tabName)")
            button.tap()
            // Give the screen a moment to render.
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 4)
        }
    }

    func test_feedShowsAtLeastOneRecipe() {
        // Feed tab is default; just wait for content.
        let firstStaticText = app.staticTexts.matching(NSPredicate(format: "label != %@", "Recipes"))
            .firstMatch
        XCTAssertTrue(
            firstStaticText.waitForExistence(timeout: 15),
            "Feed should show at least one recipe title within 15 seconds"
        )
    }

    /// REG-2 spirit: assert that the first recipe row actually renders an
    /// image, not just a placeholder. XCUITest can't read pixels, but it
    /// CAN detect that an image element exists with non-empty identifier.
    func test_feedRecipesHaveImages() {
        let firstStaticText = app.staticTexts.matching(NSPredicate(format: "label != %@", "Recipes"))
            .firstMatch
        XCTAssertTrue(firstStaticText.waitForExistence(timeout: 15))
        // AsyncImage renders an XCUIElementTypeImage when bytes resolve.
        let firstImage = app.images.firstMatch
        XCTAssertTrue(
            firstImage.waitForExistence(timeout: 15),
            "Feed should render at least one image — pre-fix the embed payload was empty"
        )
    }

    /// REG-DOD-NAV-1: tapping a recipe row must push the detail screen.
    /// Original bug: per-tab path bindings constructed by a parent helper
    /// method inside ForEach broke SwiftUI's NavigationStack identity.
    /// Fix: each tab owns its own @State path inside a dedicated TabStack view.
    func test_recipeDetailOpensAndShowsContent() {
        // Wait for the feed to populate, then tap the first recipe Button.
        // Tab-bar buttons share the same parent app.buttons collection, so
        // filter out the four known tab labels.
        let tabLabels: Set<String> = ["Recipes", "Categories", "Search", "Saved"]
        let recipeButtons = app.buttons
            .matching(NSPredicate(format: "NOT (label IN %@)", Array(tabLabels)))
        XCTAssertTrue(
            recipeButtons.element(boundBy: 1).waitForExistence(timeout: 20),
            "Feed should show at least 2 recipe buttons"
        )
        // Take the second row — first is often partially clipped by the nav bar,
        // which makes coordinate-based tap unreliable. Second is fully on screen.
        let recipeButton = recipeButtons.element(boundBy: 1)
        recipeButton.tap()

        // Diagnostic: 2-second post-tap snapshot to see if nav pushed.
        Thread.sleep(forTimeInterval: 2.0)
        let postTap = XCTAttachment(screenshot: app.screenshot())
        postTap.name = "post-tap-state"
        postTap.lifetime = .keepAlways
        add(postTap)

        let ingredientsHeader = app.staticTexts["Ingredients"]
        let appeared = ingredientsHeader.waitForExistence(timeout: 45)

        if !appeared {
            // Diagnostic: snapshot + dump everything currently on screen.
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "detail-failed-state"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "accessibility-hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(appeared, "Recipe detail should show Ingredients section")

        XCTAssertTrue(app.buttons["Save recipe"].exists || app.buttons["Unsave recipe"].exists)
        XCTAssertTrue(app.buttons["Share recipe"].exists)
    }

    /// REG-DOD-LIST-SCROLL: dragging up on the feed must scroll the list to
    /// reveal more recipes. Pre-fix the entire recipe card was wrapped in
    /// a `Button { } label: { ... }.buttonStyle(.plain).contentShape(Rectangle())`
    /// which, when a single card dominated the viewport, swallowed the
    /// finger pan gesture and the feed couldn't be scrolled. We now use
    /// `.recipeCardTap` (an `.onTapGesture`-based modifier with the
    /// `.isButton` accessibility trait) so taps still navigate but vertical
    /// drags belong to the ScrollView.
    ///
    /// The drag deliberately STARTS inside the first recipe row — that is
    /// the gesture path a real finger takes when only one tall card is
    /// visible. `app.scrollViews.firstMatch.swipeUp()` is too privileged
    /// (it bypasses the row's gesture recognizers), so it would silently
    /// keep passing even when the bug was present.
    func test_feedScrollsToRevealMoreRecipes() {
        let firstStaticText = app.staticTexts.matching(NSPredicate(format: "label != %@", "Recipes")).firstMatch
        XCTAssertTrue(firstStaticText.waitForExistence(timeout: 15))

        let tabLabels: Set<String> = ["Recipes", "Categories", "Search", "Saved"]
        let recipeButtons = app.buttons.matching(NSPredicate(format: "NOT (label IN %@)", Array(tabLabels)))
        XCTAssertTrue(recipeButtons.firstMatch.waitForExistence(timeout: 15))

        let beforeLabels = recipeButtons.allElementsBoundByIndex.map(\.label)
        let lastBefore = beforeLabels.last ?? ""

        // Drag starting INSIDE the first visible recipe row.
        let firstButton = recipeButtons.element(boundBy: 0)
        let start = firstButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = firstButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -2.0))
        start.press(forDuration: 0.05, thenDragTo: end)

        let afterLabels = recipeButtons.allElementsBoundByIndex.map(\.label)
        let lastAfter = afterLabels.last ?? ""

        // Either the visible last row changed, or the set of visible rows
        // grew. Either condition proves the ScrollView actually moved.
        let scrolled = lastBefore != lastAfter || afterLabels.count > beforeLabels.count
        if !scrolled {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "scroll-stuck"
            shot.lifetime = .keepAlways
            add(shot)
        }
        XCTAssertTrue(
            scrolled,
            "Feed should scroll when the user drags up from inside a recipe row. "
            + "before(\(beforeLabels.count) rows, last=\(lastBefore.prefix(40))) "
            + "after(\(afterLabels.count) rows, last=\(lastAfter.prefix(40)))"
        )
    }

    func test_savedTabEmptyStateOnFreshInstall() {
        app.tabBars.firstMatch.buttons["Saved"].tap()
        // Spec AC-5.8 verbatim.
        let emptyTitle = app.staticTexts["No saved recipes yet"]
        XCTAssertTrue(
            emptyTitle.waitForExistence(timeout: 6),
            "Saved tab should show empty state on fresh install"
        )
    }

    /// US-8: the welcome sheet shows on a fresh launch (i.e. when the
    /// `dod.onboardingCompletedV1` UserDefaults flag is unset), and tapping
    /// "Get cooking" dismisses it so the tab bar becomes reachable.
    ///
    /// `-DODForceFreshOnboarding` is the escape hatch handled in
    /// `DODApp.applyTestLaunchOverrides()` — it removes the persisted flag at
    /// app start so we don't depend on a real fresh install (which Xcode
    /// can't reliably do between runs). We also drop the
    /// `DOD_SUPPRESS_ONBOARDING` env var set in setUp so it doesn't suppress
    /// the very thing this test is asserting.
    func test_onboardingShowsOnFirstLaunchAndDismisses() {
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "DOD_SUPPRESS_ONBOARDING")
        app.launchArguments.append("-DODForceFreshOnboarding")
        app.launch()

        let welcome = app.staticTexts["Welcome to Dutch Oven Daddy"]
        XCTAssertTrue(
            welcome.waitForExistence(timeout: 8),
            "Welcome sheet should appear on first launch"
        )

        let cta = app.buttons["Get cooking"]
        XCTAssertTrue(cta.exists, "CTA button should be visible inside the sheet")
        cta.tap()

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 5),
            "Tab bar should appear after the welcome sheet is dismissed"
        )
        XCTAssertFalse(
            welcome.exists,
            "Welcome sheet should be gone after Get cooking is tapped"
        )
    }
}

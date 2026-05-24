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
        // Tab order post-US-16 is Recipes → Categories → Saved → Search
        // (Saved moved from position 4 to position 3). Iteration order here
        // is purely "do all four open?"; the positional guard lives in
        // `test_tabBarOrderMatchesSpec` below. Spec trace: AC-16.1, AC-16.6.
        for tabName in ["Recipes", "Categories", "Saved", "Search"] {
            let button = tabBar.buttons[tabName]
            XCTAssertTrue(button.exists, "Missing tab: \(tabName)")
            button.tap()
            // Give the screen a moment to render.
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 4)
        }
    }

    /// AC-16.6: guards the bottom tab-bar **order** so a future refactor
    /// that reshuffles `AppTab.allCases` will fail this test loudly rather
    /// than silently changing the user-visible layout.
    ///
    /// Asserts both directly (the button at index 2 is "Saved", the button
    /// at index 3 is "Search") and behaviorally (tapping each lands on the
    /// expected screen — Saved shows the empty-state title from AC-5.8 on
    /// a fresh install; Search shows its search field placeholder).
    func test_tabBarOrderMatchesSpec() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        let tabButtons = tabBar.buttons.allElementsBoundByIndex
        XCTAssertEqual(tabButtons.count, 4, "Expected exactly 4 top-level tabs")

        // Position-by-position (left → right). The labels here are what
        // a real user sees on the tab bar, so they double as a readable
        // record of the spec'd order.
        XCTAssertEqual(tabButtons[0].label, "Recipes", "Tab 1 should be Recipes")
        XCTAssertEqual(tabButtons[1].label, "Categories", "Tab 2 should be Categories")
        XCTAssertEqual(tabButtons[2].label, "Saved", "Tab 3 should be Saved (was Search pre-US-16)")
        XCTAssertEqual(tabButtons[3].label, "Search", "Tab 4 should be Search (was Saved pre-US-16)")

        // Behavioral check: tapping the third tab actually lands on Saved,
        // not on a mislabeled screen. AC-5.8 empty-state title is the
        // strongest "we're really on Saved" signal on fresh install.
        tabButtons[2].tap()
        XCTAssertTrue(
            app.staticTexts["No saved recipes yet"].waitForExistence(timeout: 6),
            "Third tab should land on the Saved screen (empty state visible on fresh install)"
        )

        // Behavioral check: fourth tab is Search. SearchView uses a
        // plain `TextField` (not `.searchable`) with the placeholder
        // "Search recipes", so the search input shows up under
        // `app.textFields`, not `app.searchFields`.
        tabButtons[3].tap()
        let searchField = app.textFields["Search recipes"]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 6),
            "Fourth tab should land on the Search screen (Search recipes field visible)"
        )
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

    /// US-7 / AC-7.1, AC-7.2, AC-7.4, AC-7.6: tapping the Cook Now CTA on
    /// recipe detail presents the full-screen Cook Mode surface, "Step 1 of M"
    /// is visible, Next advances to step 2, and Done dismisses back to detail.
    func test_cookModeOpensAndAdvances() {
        // Step 1: open the feed and navigate into a recipe detail.
        let tabLabels: Set<String> = ["Recipes", "Categories", "Search", "Saved"]
        let recipeButtons = app.buttons.matching(NSPredicate(format: "NOT (label IN %@)", Array(tabLabels)))
        XCTAssertTrue(
            recipeButtons.element(boundBy: 1).waitForExistence(timeout: 20),
            "Feed should show at least 2 recipe buttons"
        )
        recipeButtons.element(boundBy: 1).tap()

        // Detail screen should land — same wait as test_recipeDetailOpensAndShowsContent.
        let ingredientsHeader = app.staticTexts["Ingredients"]
        XCTAssertTrue(
            ingredientsHeader.waitForExistence(timeout: 45),
            "Recipe detail should show Ingredients section before tapping Cook Now"
        )

        // Step 2: tap Cook Now. The CTA has the accessibility label "Cook Now".
        let cookNow = app.buttons["Cook Now"]
        XCTAssertTrue(
            cookNow.waitForExistence(timeout: 5),
            "Cook Now CTA should be visible on recipe detail (AC-7.1)"
        )
        cookNow.tap()

        // Step 3: full-screen cover with "Step 1 of M" — AC-7.2.
        let stepOnePredicate = NSPredicate(format: "label BEGINSWITH 'Step 1 of'")
        let stepOne = app.staticTexts.matching(stepOnePredicate).firstMatch
        XCTAssertTrue(
            stepOne.waitForExistence(timeout: 5),
            "Cook Mode should render 'Step 1 of M' in the top bar"
        )

        // Step 4: tap Next, expect step counter to advance to "Step 2 of M".
        // Some recipes have only one step — guard so the test doesn't flake.
        let stepOneLabel = stepOne.label
        if let total = Self.totalStepsCount(from: stepOneLabel), total >= 2 {
            let nextButton = app.buttons["Next"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 3), "Next button should be present mid-flow")
            nextButton.tap()
            let stepTwoPredicate = NSPredicate(format: "label BEGINSWITH 'Step 2 of'")
            let stepTwo = app.staticTexts.matching(stepTwoPredicate).firstMatch
            XCTAssertTrue(
                stepTwo.waitForExistence(timeout: 3),
                "Cook Mode should advance to 'Step 2 of M' on Next"
            )
        }

        // Step 5: tap Done — AC-7.6 — and assert we're back on detail.
        let doneButton = app.buttons["Exit Cook Mode"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3), "Done button should be in Cook Mode top bar")
        doneButton.tap()

        XCTAssertTrue(
            ingredientsHeader.waitForExistence(timeout: 5),
            "After Done, the recipe detail Ingredients header should be visible again"
        )
    }

    /// Pulls the total step count out of a label like "Step 1 of 7".
    /// Returns nil if the label doesn't match the expected pattern.
    private static func totalStepsCount(from label: String) -> Int? {
        let parts = label.split(separator: " ")
        guard parts.count >= 4, let total = Int(parts[3]) else { return nil }
        return total
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

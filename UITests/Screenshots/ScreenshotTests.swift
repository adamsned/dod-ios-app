import XCTest

/// App Store marketing screenshots. Drives the app through the 5 carousel
/// surfaces (Feed → Detail hero → Detail instructions → Search → Saved) and
/// writes a PNG per surface to the marketing screenshots directory.
///
/// Invocation pattern (see `Marketing/Screenshots/README.md`):
///
///     # iPhone 6.7" — iPhone 17 Pro Max
///     TEST_RUNNER_DOD_SCREENSHOT_OUTPUT_DIR="$PWD/Marketing/Screenshots" \
///     TEST_RUNNER_DOD_SCREENSHOT_DEVICE_PREFIX="iphone-6.7" \
///     xcodebuild test \
///         -project DODApp.xcodeproj \
///         -scheme DODApp \
///         -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
///         -only-testing:DODAppUITests/ScreenshotTests \
///         -derivedDataPath build/screenshots
///
/// `TEST_RUNNER_*` env vars are stripped of their prefix by xcodebuild and
/// forwarded into the test-runner process — that's how the runtime here
/// reads them via `ProcessInfo.processInfo.environment`.
///
/// PNGs are written via `Data.write(to:)` directly to the host filesystem.
/// XCTAttachment lifetime tracks the .xcresult bundle which is awkward to
/// unpack; writing the file out-of-band keeps the deliverable a flat
/// directory of named PNGs the user can drag straight into App Store
/// Connect.
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    /// Resolved at setUp from TEST_RUNNER_DOD_SCREENSHOT_OUTPUT_DIR — falls
    /// back to a derived-data subpath if unset (useful when running through
    /// Xcode UI), and the test still passes; the artifact path just lands
    /// inside the test bundle.
    private var outputDir: URL!

    /// Resolved at setUp from TEST_RUNNER_DOD_SCREENSHOT_DEVICE_PREFIX —
    /// expected values "iphone-6.7" or "ipad-13" matching the file-naming
    /// convention in Marketing/Screenshots/README.md. Defaults to "device"
    /// so a misconfigured invocation still writes something inspectable.
    private var devicePrefix: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Skip the welcome sheet — same env var SmokeTests / E2E suites use.
        // We want every shot to start from the tab bar, not the onboarding
        // overlay.
        app.launchEnvironment["DOD_SUPPRESS_ONBOARDING"] = "1"
        // REG-1: avoid the TelemetryDeck pre-init crash path.
        app.launchEnvironment["DOD_FORCE_NO_TELEMETRY_APPID"] = "1"

        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default

        if let dirPath = env["DOD_SCREENSHOT_OUTPUT_DIR"], !dirPath.isEmpty {
            outputDir = URL(fileURLWithPath: dirPath, isDirectory: true)
        } else {
            // Fallback: tmp dir so the file is at least findable in CI logs.
            outputDir = fileManager.temporaryDirectory
                .appendingPathComponent("DODScreenshots", isDirectory: true)
        }
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

        devicePrefix = env["DOD_SCREENSHOT_DEVICE_PREFIX"].flatMap { $0.isEmpty ? nil : $0 } ?? "device"

        app.launch()
    }

    // MARK: - Capture orchestration

    /// Walks the 5 carousel surfaces in order. Each `capture(...)` call
    /// blocks until the surface is ready (or times out), then writes the
    /// PNG to disk. We deliberately drive everything in one test method so
    /// a single `xcodebuild test` invocation produces the full deck —
    /// re-launching the app between every shot would cost ~5s each (cold
    /// network fetch) and risks the SwiftData saved-recipe state diverging
    /// between captures.
    func test_capture_all_marketing_shots() throws {
        // Wait for the chrome to settle — either a tab bar (iPhone, compact
        // horizontal size class) OR a NavigationSplitView sidebar (iPad,
        // regular horizontal size class). RootView.body branches on
        // `horizontalSizeClass` (see App/RootView.swift:48). On iPad the
        // sidebar exposes the same four destination labels but lives under
        // an `app.navigationBars["DOD"]` / List rather than a bottom
        // `tabBars` element — which is why a tab-bar-only assertion fails
        // on the iPad sim.
        let tabBarReady = app.tabBars.firstMatch.waitForExistence(timeout: 12)
        let sidebarReady = app.navigationBars["DOD"].waitForExistence(timeout: 1)
        XCTAssertTrue(
            tabBarReady || sidebarReady,
            "Either tab bar (iPhone) or DOD sidebar (iPad) should appear within 12s of launch"
        )

        // iPad NavigationSplitView starts at the feed (the first sidebar
        // item is selected by default), so the feed should still load
        // automatically.
        let firstRecipeText = app.staticTexts.matching(
            NSPredicate(format: "label != %@", "Recipes")
        ).firstMatch
        XCTAssertTrue(
            firstRecipeText.waitForExistence(timeout: 25),
            "Feed should populate at least one recipe within 25s (network fetch)"
        )
        // Extra settle for AsyncImage decode — without this the hero
        // images sometimes show the placeholder color.
        sleep(3)

        // 1. Feed
        capture(name: "1-feed")

        // Save a few recipes BEFORE the detail captures so the Saved
        // tab has content for shot 5. Walk a bit deeper than 3 to absorb
        // the inevitable "row N is a roundup post whose JSON-LD parse
        // fails so detail never lands" misses — see AC-4.11 auto-dismiss
        // path. Walking 6 rows reliably lands 3-4 successful saves on
        // the live blog.
        saveTopRecipes(count: 6)

        // 2. Recipe detail — hero + start of ingredients.
        try captureRecipeDetailHero()

        // 3. Recipe detail — instructions, with one ingredient checked.
        try captureRecipeDetailInstructions()

        // 4. Search
        try captureSearch()

        // 5. Saved
        try captureSaved()
    }

    // MARK: - Surface helpers

    /// Saves the first `count` recipes from the feed by:
    ///   1. Tapping the row
    ///   2. Waiting for detail
    ///   3. Tapping "Save recipe" (skip if already saved)
    ///   4. Popping back to feed by tapping the Recipes tab twice (the
    ///      second tap on a selected tab pops the NavigationStack to root,
    ///      which is the iOS convention SwiftUI honors out of the box).
    /// Labels of non-recipe chrome buttons that appear in `app.buttons`
    /// at the top of the Recipes feed and need to be filtered out before
    /// indexing into recipe rows. Discovered empirically — there's no
    /// stable accessibility identifier separating them. iPad sidebar adds
    /// "DOD" + the iPad navigation back chevron isn't here because it
    /// shows up as a NavigationBar button instead.
    private static let feedChromeLabels: Set<String> = [
        "Recipes", "Categories", "Saved", "Search",
        "Recipes & Articles",  // iPad sidebar uses `tab.title`, not `tabLabel`
        "Layout, gallery", "Layout, list",
        "Settings", "Filter",
        "DOD",
        // iPad NavigationSplitView chrome.
        "Hide Sidebar", "Show Sidebar", "Toggle Sidebar",
        "Back", "Done",
    ]

    /// Whether the test is running on an iPad-shaped device (regular
    /// horizontal size class → NavigationSplitView sidebar). Heuristic:
    /// if a bottom `tabBars` element exists, we're on iPhone; otherwise
    /// iPad.
    private var isIPad: Bool {
        !app.tabBars.firstMatch.exists
    }

    /// Switch to the named top-level destination — works for both iPhone
    /// (bottom tab bar) and iPad (NavigationSplitView sidebar). On iPad
    /// the sidebar List exposes each tab as a cell labeled with
    /// `tab.title` (e.g. "Recipes & Articles", not "Recipes"), so callers
    /// have to pass both the short and long form.
    private func switchToTab(short: String, long: String? = nil) {
        if isIPad {
            // Try multiple element types — SwiftUI's `List(selection:)`
            // with `Label(systemImage:)` rows can expose the row as a
            // Button (iOS 17+), a StaticText, or a Cell depending on
            // OS version and layout. We probe each, preferring the
            // long-form `tab.title` label that iPadSplit uses.
            let labelToFind = long ?? short
            // Probe each element type in order of specificity. The
            // sidebar item is a Cell on iOS 17+ iPad and contains the
            // Label's static text — when both forms exist, the Cell
            // is the correct tap target (it sets the List selection,
            // unlike a bare StaticText which is non-interactive). We
            // use the firstMatch variant on each query because the
            // long-form `tab.title` may appear both in the sidebar
            // and in the detail's navigation title.
            let candidates: [XCUIElement] = [
                app.cells.matching(identifier: labelToFind).firstMatch,
                app.cells.matching(identifier: short).firstMatch,
                app.buttons.matching(identifier: labelToFind).firstMatch,
                app.buttons.matching(identifier: short).firstMatch,
                app.staticTexts.matching(identifier: labelToFind).firstMatch,
                app.staticTexts.matching(identifier: short).firstMatch,
            ]
            for candidate in candidates where candidate.waitForExistence(timeout: 1) {
                // Some sidebar StaticTexts are hit-testable; some are not.
                // Tapping a non-hit-testable element is a no-op but won't
                // throw; the next iteration handles the fallback. We
                // explicitly check isHittable to avoid tapping a label
                // that's behind the detail view.
                if candidate.isHittable {
                    candidate.tap()
                    return
                }
            }
            // Last-resort diagnostic dump so the next iteration sees what
            // the iPad sidebar actually exposes.
            let dump = XCTAttachment(string: app.debugDescription)
            dump.name = "ipad-sidebar-hierarchy-on-\(short)"
            dump.lifetime = .keepAlways
            add(dump)
            XCTFail("Could not find iPad sidebar entry for '\(short)' / '\(long ?? "—")'")
        } else {
            app.tabBars.firstMatch.buttons[short].tap()
        }
    }

    private func saveTopRecipes(count: Int) {
        // Make sure we're on the Recipes destination + at root. On iPhone
        // double-tap pops the stack to root; on iPad selecting the sidebar
        // item re-instantiates the detail via `.id(selectedTab)` so a
        // single select is sufficient.
        switchToTab(short: "Recipes", long: "Recipes & Articles")
        if !isIPad {
            // iPhone-only — second tap on the active tab pops to root.
            usleep(200_000)
            app.tabBars.firstMatch.buttons["Recipes"].tap()
        }
        _ = app.staticTexts.matching(
            NSPredicate(format: "label IN %@", ["Recipes", "Recipes & Articles"])
        ).firstMatch.waitForExistence(timeout: 4)

        for index in 0..<count {
            let recipeButtons = app.buttons.matching(
                NSPredicate(format: "NOT (label IN %@)", Array(Self.feedChromeLabels))
            )
            guard recipeButtons.element(boundBy: index).waitForExistence(timeout: 8) else {
                continue
            }
            let label = recipeButtons.element(boundBy: index).label
            recipeButtons.element(boundBy: index).tap()
            print("DOD_SCREENSHOT_SAVE_WALK row \(index) tapped: \(label.prefix(60))")

            // Wait for detail.
            let ingredients = app.staticTexts["Ingredients"]
            guard ingredients.waitForExistence(timeout: 30) else {
                print("DOD_SCREENSHOT_SAVE_WALK row \(index) detail never loaded")
                popToFeedRoot()
                continue
            }

            // Save if not already saved.
            let saveButton = app.buttons["Save recipe"]
            if saveButton.waitForExistence(timeout: 3) {
                saveButton.tap()
                let flipped = app.buttons["Unsave recipe"].waitForExistence(timeout: 5)
                print("DOD_SCREENSHOT_SAVE_WALK row \(index) saved (flipped=\(flipped))")
            } else if app.buttons["Unsave recipe"].exists {
                print("DOD_SCREENSHOT_SAVE_WALK row \(index) already saved — leaving as-is")
            } else {
                print("DOD_SCREENSHOT_SAVE_WALK row \(index) neither Save nor Unsave button found")
            }

            popToFeedRoot()
        }
    }

    /// Returns the Recipes tab to its root. Double-tap on the selected
    /// tab is the standard iOS gesture to pop to root and SwiftUI honors
    /// it for NavigationStack. Falls back to a tab-swap (Categories →
    /// Recipes) which also resets the nav stack on a re-entry tap in
    /// practice for this app's path-binding model.
    private func popToFeedRoot() {
        if isIPad {
            // iPad: jump to Saved first so reselecting Recipes actually
            // fires the `.id(selectedTab)`-driven detail re-instantiation
            // (selecting the same item is a no-op).
            switchToTab(short: "Saved")
            usleep(200_000)
            switchToTab(short: "Recipes", long: "Recipes & Articles")
        } else {
            // iPhone: double-tap pops to root.
            let tabBar = app.tabBars.firstMatch
            tabBar.buttons["Recipes"].tap()
            usleep(200_000)
            tabBar.buttons["Recipes"].tap()
        }
        // Wait for the feed list to be reachable again.
        _ = app.staticTexts.matching(
            NSPredicate(format: "label IN %@", ["Recipes", "Recipes & Articles"])
        ).firstMatch.waitForExistence(timeout: 5)
    }

    /// Open a visually appealing recipe (try one toward the top, ideally
    /// row 1) and take a screenshot positioned near the top so the hero
    /// image is in view.
    private func captureRecipeDetailHero() throws {
        // Make sure we're at the feed root before navigating in.
        popToFeedRoot()

        // Look for "bourbon" first (the README's preferred recipe). The
        // chrome filter is wider than the simple tab-labels list because
        // the feed exposes "Layout, gallery" and "Settings" buttons too.
        let bourbon = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'bourbon' AND NOT (label IN %@)",
                        Array(Self.feedChromeLabels))
        ).firstMatch

        if bourbon.waitForExistence(timeout: 2) {
            bourbon.tap()
        } else {
            let recipeButtons = app.buttons.matching(
                NSPredicate(format: "NOT (label IN %@)", Array(Self.feedChromeLabels))
            )
            XCTAssertTrue(
                recipeButtons.element(boundBy: 1).waitForExistence(timeout: 10),
                "Need at least 2 recipe rows to tap row 1"
            )
            recipeButtons.element(boundBy: 1).tap()
        }

        XCTAssertTrue(
            app.staticTexts["Ingredients"].waitForExistence(timeout: 30),
            "Recipe detail Ingredients header should be visible for hero shot"
        )

        // Hero shot is at scroll-top — hero image + title + Cook Now CTA
        // + QuickJump tabs. This is the README's intended carousel
        // opening for the detail: show the visual punch first; the
        // ingredients-on-screen variant is shot 3 (instructions) and the
        // hero shot trades a few visible ingredient rows for the hero
        // image which is what sells the recipe.
        sleep(2)
        capture(name: "2-detail-hero")
    }

    /// On the same detail screen, jump to the Instructions section via
    /// the QuickJump tab and capture. Also tap one ingredient checkbox
    /// first so the UI shows interactivity is wired up (the checkmark
    /// will be visible if the user scrolls back, and on the Cook Mode
    /// state — but mainly it leaves the recipe in a "started cooking"
    /// state that matches the carousel narrative).
    private func captureRecipeDetailInstructions() throws {
        // Toggle one ingredient checkbox while still on the Ingredients
        // section. Ingredient rows are accessibility-labeled with the
        // ingredient TEXT itself (see IngredientCheckRow), so we search
        // for any button containing "cup" / "teaspoon" / "tablespoon" /
        // "ounce" — common units that uniquely identify ingredient rows
        // (none of the chrome buttons match these tokens).
        let unitPattern = NSPredicate(format:
            "label CONTAINS[c] 'cup' OR label CONTAINS[c] 'teaspoon' OR " +
            "label CONTAINS[c] 'tablespoon' OR label CONTAINS[c] 'ounce' OR " +
            "label CONTAINS[c] 'tsp' OR label CONTAINS[c] 'tbsp'"
        )
        let ingredientRows = app.buttons.matching(unitPattern)
        if ingredientRows.firstMatch.waitForExistence(timeout: 3) {
            ingredientRows.firstMatch.tap()
            sleep(1)
        }

        // Jump to the Instructions section via QuickJump.
        let instructionsJump = app.buttons["Instructions"]
        if instructionsJump.waitForExistence(timeout: 3) {
            instructionsJump.tap()
        }

        sleep(2)
        capture(name: "3-detail-instructions")
    }

    /// Switch to the Search tab and type a query that reliably returns
    /// multiple results.
    private func captureSearch() throws {
        switchToTab(short: "Search")
        let searchField = app.textFields["Search recipes"]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Search field should appear after switching to Search tab"
        )
        searchField.tap()
        searchField.typeText("skillet")

        // Wait for results. 30s — live WP REST round-trip can be slow.
        let filterChrome: Set<String> = [
            "All categories", "Any time", "Recently viewed",
            "Search filters", "Clear",
        ]
        let tabLabels: Set<String> = ["Recipes", "Categories", "Saved", "Search"]
        let exclude = tabLabels.union(filterChrome)
        let resultButtons = app.buttons.matching(
            NSPredicate(format: "NOT (label IN %@) AND NOT (label BEGINSWITH 'Try')", Array(exclude))
        )
        // Either results land OR the empty-state "No results" lands — but
        // we proceed with the capture regardless so the user sees the
        // current behavior.
        _ = resultButtons.firstMatch.waitForExistence(timeout: 25)
        // Dismiss the keyboard so it doesn't cover results. The "return"
        // key (often labeled "Search" on iOS but accessibility-labeled
        // "return") may not be present; fall back to tapping outside the
        // search field. On iPad the keyboard split-bar adds a "Search"
        // button which we try first.
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            if keyboard.buttons["Search"].exists {
                keyboard.buttons["Search"].tap()
            } else if keyboard.buttons["return"].exists {
                keyboard.buttons["return"].tap()
            } else if keyboard.buttons["Return"].exists {
                keyboard.buttons["Return"].tap()
            } else {
                // Last-resort: tap a result row, but that navigates. So
                // just leave keyboard visible — the search results above
                // are still visible.
            }
        }
        sleep(2)
        capture(name: "4-search")
    }

    /// Switch to the Saved tab and capture the populated state.
    private func captureSaved() throws {
        switchToTab(short: "Saved")
        // Wait for either a row OR the empty-state title.
        _ = app.buttons.firstMatch.waitForExistence(timeout: 6)
        sleep(2)
        capture(name: "5-saved")
    }

    // MARK: - Capture primitive

    /// Captures the full-screen screenshot and writes it as a PNG to
    /// `outputDir/<devicePrefix>-<name>.png`.
    ///
    /// Also attaches the screenshot to the .xcresult bundle so it shows up
    /// in Xcode Test reports — useful for debugging when the on-disk write
    /// fails (sandboxing, permissions, etc.).
    private func capture(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let pngData = screenshot.pngRepresentation

        let fileName = "\(devicePrefix!)-\(name).png"
        let fileURL = outputDir.appendingPathComponent(fileName)

        do {
            try pngData.write(to: fileURL, options: .atomic)
            // Mirror the on-disk path in test output so the parent shell
            // process can grep it out without scraping .xcresult.
            print("DOD_SCREENSHOT_WRITTEN \(fileURL.path)")
        } catch {
            XCTFail("Failed to write screenshot \(fileName) to \(fileURL.path): \(error)")
        }

        // Keep an XCTAttachment too for Xcode UI.
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

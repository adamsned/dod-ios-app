import XCTest

/// L5 hermetic journeys for the three Cooking Tools hub cards not covered by
/// the existing E2E suite:
///
///   1. **Heat Coach** — `hub-heat-coach` → the sheet opens; any element whose
///      accessibility label contains "Starting coals: about N …" is present
///      (the diagram's combined `.accessibilityLabel` via `NSPredicate`), and
///      the `heat-coach-oven-size` stepper exists in the adjacent setup card.
///      Pure calculator — no network, no persistence.
///
///   2. **Cooking Journal empty state** — `hub-journal` → on a fresh in-memory
///      launch (no cooks logged yet) the journal opens and shows the "No Cooks
///      Logged Yet" empty-state copy. Distinct from
///      `CookJournalJourneyE2ETests.test_log_cook_appears_in_cooking_journal`,
///      which logs a cook first. The in-memory store resets every launch, so the
///      empty state is guaranteed deterministic.
///
///   3. **First Cookout chooser** — `hub-first-cookout` → the roadmap picker
///      presents, identified by `cook-chooser-subheader` on the header
///      description and at least one `cook-chooser-rung-{id}` path-node card.
///      Static data (`GuidedCookout.path`) — hermetic.
///
/// All identifiers were verified against source before writing:
///   - `hub-heat-coach`, `hub-journal`, `hub-first-cookout`:
///       `App/CookingToolsHubView+ToolCards.swift`
///   - `heat-coach-result` (VStack container, surfaces as group):
///       `Packages/DODFeatureFeed/…/HeatCoachView+Sections.swift`
///   - `heat-coach-diagram` (`.accessibilityLabel` "Starting coals: about N…"):
///       `Packages/DODFeatureFeed/…/HeatCoachView+Diagram.swift`
///       — queried by label, not identifier; absorbed by `heat-coach-result`
///         group in XCUITest's accessibility tree.
///   - `heat-coach-setup` (VStack container for the inputs card):
///       `Packages/DODFeatureFeed/…/HeatCoachView+Sections.swift`
///       — `heat-coach-oven-size` is inside this group and absorbed by it;
///         the container identifier is used for the assertion instead.
///   - "No Cooks Logged Yet":
///       `Packages/DODFeatureFeed/…/CookJournalView.swift` (`emptyState`)
///   - `cook-chooser-subheader`:
///       `Packages/DODFeatureFeed/…/CookChooserFlow.swift` (`header`)
///   - `cook-chooser-rung-{id}`:
///       `Packages/DODFeatureFeed/…/CookChooserFlow+PathNode.swift` (`card`)
///
/// SKIPPED candidates:
///   - Cook Mode explainer card (`hub-cook-mode`): the sheet has a
///     `hub-cook-mode-find-recipe` button but also the "Find a Recipe" CTA
///     triggers `onFindRecipe()` which routes to the Recipes tab via the host
///     `RootView` injection — not a hermetically-testable sheet interaction
///     without wiring a tab-switch assertion that depends on unstable state.
///     The Cook Mode surface itself lives in recipe detail, already covered by
///     `CookJournalJourneyE2ETests`.
///   - Buy BuzzyWaxx (`hub-buy-buzzywaxx`): hands off to the system browser
///     via `openURL` — not hermetic (requires Safari or system alert).
@MainActor
final class ToolsHubJourneysE2ETests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - 1. Heat Coach opens and displays a coal estimate

    /// Tools tab → `hub-heat-coach` → the Heat Coach sheet opens → the answer
    /// card (`heat-coach-result`) is visible → an element with accessibility
    /// label containing "Starting coals: about N …" is present (the diagram's
    /// combined label) → the setup card (`heat-coach-setup`) is also on screen.
    /// No network; pure local calculator.
    ///
    /// SwiftUI renders VStack containers with `.accessibilityIdentifier()` as
    /// single accessibility groups: child identifiers (`heat-coach-diagram`,
    /// `heat-coach-cook-time`, `heat-coach-oven-size`) are absorbed by their
    /// parent group and cannot be queried individually in XCUITest. The coal
    /// estimate is therefore matched by the diagram's `.accessibilityLabel`
    /// content via `NSPredicate`, and the setup card is matched by its own
    /// container identifier rather than the stepper within it.
    func test_heat_coach_opens_and_displays_coal_estimate() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        tabBar.buttons["Tools"].tap()

        let heatCoachCard = app.buttons["hub-heat-coach"]
        XCTAssertTrue(
            heatCoachCard.waitForExistence(timeout: 8),
            "the Tools hub should expose the Heat Coach tool card"
        )
        heatCoachCard.tap()

        // The hub presents HeatCoachView wrapped in a NavigationStack; the nav
        // title "Heat Coach" appears once the sheet is on screen.
        XCTAssertTrue(
            app.navigationBars["Heat Coach"].waitForExistence(timeout: 10),
            "the Heat Coach sheet should present its 'Heat Coach' navigation title"
        )

        // The answer card is the first visible element — it must be on screen
        // immediately (no async load; the model is computed synchronously).
        let resultCard = app.descendants(matching: .any)
            .matching(identifier: "heat-coach-result")
            .firstMatch
        XCTAssertTrue(
            resultCard.waitForExistence(timeout: 8),
            "the Heat Coach should show the answer card (heat-coach-result)"
        )

        // The coal-split diagram has identifier "heat-coach-diagram" in source, but
        // its `.accessibilityElement(children: .ignore)` VStack is nested inside the
        // `heat-coach-result` container, which can absorb inner elements in the
        // XCUITest accessibility tree. Query by the diagram's LABEL content instead:
        // the combined VoiceOver label for the diagram is always
        //   "Starting coals: about N — M on the lid, P underneath."
        // This matches regardless of whether the element surfaces under its own
        // identifier or is absorbed into the parent container's label.
        let hasCoalEstimate = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Starting coals"))
            .firstMatch
        XCTAssertTrue(
            hasCoalEstimate.waitForExistence(timeout: 8),
            "the Heat Coach should display an element whose accessibility label "
                + "contains the coal estimate ('Starting coals: about N ...')"
        )

        // The primary-inputs card (heat-coach-setup) is a separate container from
        // the answer card. Verify the card itself is on screen, confirming the
        // full layout rendered (answer + setup controls together). Note: the
        // stepper identifier `heat-coach-oven-size` is inside this VStack group
        // and is absorbed by the group (same behavior as heat-coach-result), so
        // the container-level identifier is asserted here instead.
        let setupCard = app.descendants(matching: .any)
            .matching(identifier: "heat-coach-setup")
            .firstMatch
        XCTAssertTrue(
            setupCard.waitForExistence(timeout: 8),
            "the Heat Coach should show the primary setup card (heat-coach-setup) "
                + "below the answer card"
        )
    }

    // MARK: - 2. Cooking Journal shows its empty state on a fresh launch

    /// Tools tab → `hub-journal` → the journal sheet opens → on a clean
    /// in-memory launch (no cooks logged) the "No Cooks Logged Yet" empty-state
    /// copy appears once the async load resolves. The in-memory store resets on
    /// every E2E launch, guaranteeing the empty-state branch every time.
    ///
    /// Distinct from `CookJournalJourneyE2ETests.test_log_cook_appears_in_cooking_journal`,
    /// which writes a cook first and then asserts the non-empty journal list.
    func test_cooking_journal_empty_state_on_fresh_launch() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        tabBar.buttons["Tools"].tap()

        let journalCard = app.buttons["hub-journal"]
        XCTAssertTrue(
            journalCard.waitForExistence(timeout: 8),
            "the Tools hub should expose the Cooking Journal tool card"
        )
        journalCard.tap()

        // CookJournalView is a NavigationStack with title "Cooking Journal".
        XCTAssertTrue(
            app.navigationBars["Cooking Journal"].waitForExistence(timeout: 10),
            "the Cooking Journal sheet should present its 'Cooking Journal' navigation title"
        )

        // CookJournalView.contentState: starts .loading (ProgressView), then
        // transitions to .empty once the async load resolves with an empty array.
        // Use a generous timeout to let the `.task` complete.
        XCTAssertTrue(
            app.staticTexts["No Cooks Logged Yet"].waitForExistence(timeout: 12),
            "the Cooking Journal should show its empty-state heading on a fresh "
                + "in-memory launch (no cooks exist yet)"
        )
    }

    // MARK: - 3. First Cookout chooser presents the guided roadmap

    /// Tools tab → `hub-first-cookout` → the `CookChooserFlow` roadmap picker
    /// presents → the header's `cook-chooser-subheader` identifier is visible →
    /// at least one path-node card (`cook-chooser-rung-{id}`) exists. Static
    /// data (`GuidedCookout.path`); no network dependency.
    func test_first_cookout_chooser_presents_roadmap() {
        app.launchForE2E()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "tab bar should appear")

        tabBar.buttons["Tools"].tap()

        let firstCookoutCard = app.buttons["hub-first-cookout"]
        XCTAssertTrue(
            firstCookoutCard.waitForExistence(timeout: 8),
            "the Tools hub should expose the First Cookout tool card"
        )
        firstCookoutCard.tap()

        // CookChooserFlow's picker renders a NavigationStack whose header contains
        // the chooser description text, stamped with `cook-chooser-subheader`.
        let subheader = app.descendants(matching: .any)
            .matching(identifier: "cook-chooser-subheader")
            .firstMatch
        XCTAssertTrue(
            subheader.waitForExistence(timeout: 10),
            "the First Cookout chooser should present its roadmap header "
                + "(cook-chooser-subheader)"
        )

        // CookPathNode stamps each tappable dish card with
        // `cook-chooser-rung-{rung.recipeID}`. Assert at least one rung exists
        // (GuidedCookout.path is a fixed non-empty list; the exact recipeID is
        // not asserted because it may shift as new rungs are added).
        let anyRung = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'cook-chooser-rung-'"))
            .firstMatch
        XCTAssertTrue(
            anyRung.waitForExistence(timeout: 10),
            "the First Cookout chooser should render at least one path-rung card "
                + "(cook-chooser-rung-{id})"
        )
    }
}

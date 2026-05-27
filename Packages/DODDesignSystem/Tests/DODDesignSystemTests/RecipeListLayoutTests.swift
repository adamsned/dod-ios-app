import XCTest

@testable import DODDesignSystem

/// L1 unit coverage for `RecipeListLayout` — the shared layout preference
/// US-38 / AC-38.2 / AC-38.6 / CL-64 (T-650, 2026-05-27) introduces for
/// the `FeedView` + `SearchView` gallery/list toggle.
///
/// Pattern mirrors `SettingsViewModelTests` — drives an isolated
/// `UserDefaults(suiteName:)` so the standard defaults stay untouched
/// across test runs.
final class RecipeListLayoutTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.dutchovendaddy.tests.RecipeListLayout.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - AC-38.2 / AC-38.6 — persistence round-trip

    func test_defaultIsGalleryWhenKeyAbsent() {
        // AC-38.2 — default `.gallery` preserves CC-9's 2-col grid
        // byte-for-byte for users on first launch + pre-T-650 migrations.
        XCTAssertEqual(RecipeListLayout.fromDefaults(defaults), .gallery)
    }

    func test_roundTripsGalleryAndListThroughUserDefaults() {
        defaults.set(RecipeListLayout.list.rawValue, forKey: RecipeListLayout.storageKey)
        XCTAssertEqual(RecipeListLayout.fromDefaults(defaults), .list)

        defaults.set(RecipeListLayout.gallery.rawValue, forKey: RecipeListLayout.storageKey)
        XCTAssertEqual(RecipeListLayout.fromDefaults(defaults), .gallery)
    }

    func test_defensiveFallbackToGalleryOnMalformedRawValue() {
        // AC-38.6 — defensive fallback when a future rename or partial
        // migration leaves a value that doesn't decode to a known case.
        defaults.set("compact-not-a-real-case", forKey: RecipeListLayout.storageKey)
        XCTAssertEqual(RecipeListLayout.fromDefaults(defaults), .gallery)
    }

    // MARK: - toggle() flip behavior

    func test_toggleFlipsGalleryToList() {
        var layout = RecipeListLayout.gallery
        layout.toggle()
        XCTAssertEqual(layout, .list)
    }

    func test_toggleFlipsListToGallery() {
        var layout = RecipeListLayout.list
        layout.toggle()
        XCTAssertEqual(layout, .gallery)
    }

    // MARK: - AC-38.1 — icon convention (current-state, not destination)

    func test_galleryShowsGridIconPerCurrentStateConvention() {
        // CL-64.1 — the icon represents the CURRENT layout, not the
        // destination. In gallery, the button shows `square.grid.2x2`.
        XCTAssertEqual(RecipeListLayout.gallery.toggleIconName, "square.grid.2x2")
    }

    func test_listShowsBulletIconPerCurrentStateConvention() {
        XCTAssertEqual(RecipeListLayout.list.toggleIconName, "list.bullet")
    }

    // MARK: - AC-38.1 — accessibility shape

    func test_accessibilityLabelNamesCurrentState() {
        XCTAssertEqual(
            RecipeListLayout.gallery.currentStateAccessibilityLabel,
            "Layout, gallery"
        )
        XCTAssertEqual(
            RecipeListLayout.list.currentStateAccessibilityLabel,
            "Layout, list"
        )
    }

    func test_accessibilityHintNamesDestination() {
        // The icon hides the destination; the spoken hint makes it
        // explicit so VoiceOver + Switch Control users aren't blocked.
        XCTAssertEqual(
            RecipeListLayout.gallery.destinationActionHint,
            "switch to list"
        )
        XCTAssertEqual(
            RecipeListLayout.list.destinationActionHint,
            "switch to gallery"
        )
    }
}

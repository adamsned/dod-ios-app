#if canImport(UIKit) && canImport(WidgetKit)
import SnapshotTesting
import SwiftUI
import UIKit
import WidgetKit
import XCTest

@testable import DODDesignSystem

/// L4 baselines for the `.systemLarge` widget faces (T-768 / CL-165 /
/// DUT-74): `WidgetCard.FeaturedLarge` (hero-forward) and
/// `WidgetCard.SavedLarge` (up to 5 rows), in both `.fullColor`
/// (Standard) and `.accented` (Tinted) rendering modes.
///
/// Each render site is wrapped in `.background(DODColor.surfaceElevated)`
/// to simulate the widget's `containerBackground(for: .widget)` — the
/// same harness convention CL-164 (T-767) established for the small/medium
/// faces. The hero renders its gradient placeholder (no fixture image),
/// matching the other widget baselines. `record: .missing` lays down the
/// PNG on the first iPhone-sim run; subsequent runs diff.
@available(iOS 18.0, *)
final class WidgetLargeSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    func test_featuredLarge_populated() {
        let view = WidgetCard.FeaturedLarge(content: Self.widgetContent())
            .frame(width: 364, height: 382)
            .background(DODColor.surfaceElevated)
        assertSnapshot(of: view, as: Self.largeImage(), record: .missing)
    }

    func test_featuredLarge_populated_tinted() {
        let view = WidgetCard.FeaturedLarge(content: Self.widgetContent())
            .environment(\.widgetRenderingMode, .accented)
            .frame(width: 364, height: 382)
            .background(DODColor.surfaceElevated)
        assertSnapshot(of: view, as: Self.largeImage(), record: .missing)
    }

    /// DUT-460 — the adaptive "Latest Article" eyebrow (no recipe time chip).
    func test_featuredLarge_article() {
        let base = Self.widgetContent()
        let content = WidgetCard.Content(
            title: "Seasoning Cast Iron: The Only Guide You Need",
            excerpt: base.excerpt,
            heroImageURL: nil,
            totalTimeDisplay: nil,
            eyebrow: "Latest Article"
        )
        let view = WidgetCard.FeaturedLarge(content: content)
            .frame(width: 364, height: 382)
            .background(DODColor.surfaceElevated)
        assertSnapshot(of: view, as: Self.largeImage(), record: .missing)
    }

    func test_savedLarge_fiveEntries() {
        let view = WidgetCard.SavedLarge(rows: Self.savedSampleRows)
            .frame(width: 364, height: 382)
            .background(DODColor.surfaceElevated)
        assertSnapshot(of: view, as: Self.largeImage(), record: .missing)
    }

    func test_savedLarge_fiveEntries_tinted() {
        let view = WidgetCard.SavedLarge(rows: Self.savedSampleRows)
            .environment(\.widgetRenderingMode, .accented)
            .frame(width: 364, height: 382)
            .background(DODColor.surfaceElevated)
        assertSnapshot(of: view, as: Self.largeImage(), record: .missing)
    }

    // MARK: - Fixtures

    private static func largeImage<V: View>() -> Snapshotting<V, UIImage> {
        .image(
            precision: 0.98,
            perceptualPrecision: 0.97,
            layout: .fixed(width: 364, height: 382)
        )
    }

    private static func widgetContent() -> WidgetCard.Content {
        // Deliberately long title + excerpt: this is the real-world case
        // that clipped before T-769 / CL-166 (DUT-75). DUT-458 stresses it
        // further — a title that fills 2 full lines + a 2-line excerpt — so the
        // layout must scale text (`.minimumScaleFactor`) rather than clip the
        // last line / time chip past the frame.
        WidgetCard.Content(
            title: "Slow-Braised Short Rib Ragù over Creamy Parmesan Polenta",
            excerpt:
                "A rich, restaurant-worthy Sunday dinner that comes together in one pot with deep, savory flavor and fall-apart tender beef.",
            heroImageURL: nil,
            totalTimeDisplay: "3 hr 30 min"
        )
    }

    private static let savedSampleRows: [WidgetCard.SavedRow] = [
        .init(title: "Garlic Butter Skillet Corn"),
        .init(title: "Sourdough Bread"),
        .init(title: "Cast Iron Pizza"),
        .init(title: "Dutch Oven Chili"),
        .init(title: "Skillet Cornbread"),
    ]
}
#endif

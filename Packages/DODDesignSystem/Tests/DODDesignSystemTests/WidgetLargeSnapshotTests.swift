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
        // that clipped before T-769 / CL-166 (DUT-75). The `.fixedSize`
        // on the content stack must give both the 2-line title and the
        // 2-line excerpt their full height without the hero squeezing them.
        WidgetCard.Content(
            title: "Dutch Oven Garlic Herb Butter Roasted Chicken",
            excerpt: "A one-pot weeknight dinner with crispy skin and tender, juicy meat the whole family loves.",
            heroImageURL: nil,
            totalTimeDisplay: "1 hr 15 min"
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

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// DUT-1381 — L4 coverage for long recipe titles in the non-Medium widgets,
/// where the text was being cut off. Medium is intentionally not covered here
/// (it is correct and unchanged). `record: .missing` like the sibling widget
/// tests: first run lays down baselines, CI re-records on its renderer.
final class WidgetLongTitleSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    private static let longTitle = "Best Dutch Oven For Every Budget: 7 Pots I Actually Cook In"

    private static let longRows: [WidgetCard.SavedRow] = [
        WidgetCard.SavedRow(title: longTitle),
        WidgetCard.SavedRow(title: "Slow-Braised Short Rib Ragu over Creamy Parmesan Polenta"),
    ]

    func test_savedSmall_longTitles() {
        let view = WidgetCard.SavedSmall(rows: Self.longRows)
            .frame(width: 158, height: 158)
            .background(DODColor.surfaceElevated)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 158, height: 158)
            ),
            record: .missing
        )
    }

    func test_savedSmall_longTitles_largeDynamicType() {
        let view = WidgetCard.SavedSmall(rows: Self.longRows)
            .frame(width: 158, height: 158)
            .background(DODColor.surfaceElevated)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 158, height: 158),
                traits: UITraitCollection(preferredContentSizeCategory: .accessibilityMedium)
            ),
            record: .missing
        )
    }

    func test_featuredSmall_longTitle() {
        let view = WidgetCard.Small(content: Self.content())
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 158, height: 158)
            ),
            record: .missing
        )
    }

    private static func content() -> WidgetCard.Content {
        WidgetCard.Content(
            title: longTitle,
            excerpt: "",
            heroImageURL: nil,
            totalTimeDisplay: nil,
            eyebrow: "Latest Recipe"
        )
    }
}
#endif

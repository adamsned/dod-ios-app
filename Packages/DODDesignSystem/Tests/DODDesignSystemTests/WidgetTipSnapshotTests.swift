#if canImport(UIKit) && canImport(WidgetKit)
import SnapshotTesting
import SwiftUI
import UIKit
import WidgetKit
import XCTest

@testable import DODDesignSystem

/// L4 baselines for the home-screen Cooking Tip card (DUT-459):
/// `WidgetCard.TipCard` in the `.systemSmall` (compact square) and
/// `.systemMedium` (wide) sizes. Text-only on the (tint-aware) surface, so the
/// render site wraps in `.background(DODColor.surfaceElevated)` to simulate the
/// widget's `containerBackground(for: .widget)` — the same harness convention
/// the other widget snapshot tests use. `record: .missing` lays down the PNG on
/// the first iPhone-sim run; subsequent runs diff.
final class WidgetTipSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    private static let smallSize = CGSize(width: 158, height: 158)
    private static let mediumSize = CGSize(width: 338, height: 158)

    private static let sampleTip = "Rotate the oven a third of a turn each time you check it"

    func test_tipCard_small() {
        let view = WidgetCard.TipCard(tip: Self.sampleTip, isCompact: true)
            .frame(width: Self.smallSize.width, height: Self.smallSize.height)
            .background(DODColor.surfaceElevated)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: Self.smallSize.width, height: Self.smallSize.height)
            ),
            record: .missing
        )
    }

    func test_tipCard_medium() {
        let view = WidgetCard.TipCard(tip: Self.sampleTip, isCompact: false)
            .frame(width: Self.mediumSize.width, height: Self.mediumSize.height)
            .background(DODColor.surfaceElevated)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: Self.mediumSize.width, height: Self.mediumSize.height)
            ),
            record: .missing
        )
    }
}
#endif

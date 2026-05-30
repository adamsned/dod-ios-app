#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// L4 visual-regression tests for the saved-recipes widget (US-17).
///
/// 12 baselines: empty / 1-saved / 3-saved × small + medium × light +
/// dark. Both appearances are exercised via a `UITraitCollection` on the
/// snapshot strategy so the same SwiftUI view renders against the
/// dynamic-color asset catalogue in each mode. `record: .missing`
/// matches the surrounding US-9 widget tests — first run lays down
/// baselines, subsequent runs diff.
///
/// Lives in its own file alongside `SnapshotTests.swift` to keep both
/// under SwiftLint's file-length cap. Same harness conventions, just a
/// narrower scope (one feature, no shared fixtures with the comments /
/// ratings tests).
///
/// Spec trace: spec.md US-17, AC-17.7.
final class SavedWidgetSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an intentional
        // visual change, then revert before commit.
        isRecording = false
    }

    // MARK: - Fixtures

    private static let savedSampleRow = WidgetCard.SavedRow(
        title: "Garlic Butter Skillet Corn",
        heroImageURL: nil
    )

    private static let savedSampleRows: [WidgetCard.SavedRow] = [
        WidgetCard.SavedRow(title: "Garlic Butter Skillet Corn"),
        WidgetCard.SavedRow(title: "Sourdough Bread"),
        WidgetCard.SavedRow(title: "Cast Iron Pizza"),
    ]

    private static let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
    private static let lightTraits = UITraitCollection(userInterfaceStyle: .light)

    // MARK: - Small

    func test_savedWidget_small_oneEntry_light() {
        let view = WidgetCard.SavedSmall(row: Self.savedSampleRow)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 158, height: 158),
                traits: Self.lightTraits
            ),
            record: .missing
        )
    }

    func test_savedWidget_small_oneEntry_dark() {
        let view = WidgetCard.SavedSmall(row: Self.savedSampleRow)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 158, height: 158),
                traits: Self.darkTraits
            ),
            record: .missing
        )
    }

    /// Per CL-26 the small size only holds one recipe — when the
    /// snapshot carries more we render just the first. Pinning this
    /// keeps a future "render all three on small" mistake out of the
    /// build.
    func test_savedWidget_small_threeEntries_takesFirstOnly_light() {
        let view = WidgetCard.SavedSmall(row: Self.savedSampleRows[0])
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 158, height: 158),
                traits: Self.lightTraits
            ),
            record: .missing
        )
    }

    func test_savedWidget_small_threeEntries_takesFirstOnly_dark() {
        let view = WidgetCard.SavedSmall(row: Self.savedSampleRows[0])
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 158, height: 158),
                traits: Self.darkTraits
            ),
            record: .missing
        )
    }

    // MARK: - Medium

    func test_savedWidget_medium_oneEntry_light() {
        let view = WidgetCard.SavedMedium(rows: Array(Self.savedSampleRows.prefix(1)))
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 338, height: 158),
                traits: Self.lightTraits
            ),
            record: .missing
        )
    }

    func test_savedWidget_medium_oneEntry_dark() {
        let view = WidgetCard.SavedMedium(rows: Array(Self.savedSampleRows.prefix(1)))
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 338, height: 158),
                traits: Self.darkTraits
            ),
            record: .missing
        )
    }

    func test_savedWidget_medium_threeEntries_light() {
        let view = WidgetCard.SavedMedium(rows: Self.savedSampleRows)
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 338, height: 158),
                traits: Self.lightTraits
            ),
            record: .missing
        )
    }

    func test_savedWidget_medium_threeEntries_dark() {
        let view = WidgetCard.SavedMedium(rows: Self.savedSampleRows)
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 338, height: 158),
                traits: Self.darkTraits
            ),
            record: .missing
        )
    }

    // MARK: - Empty (CL-27 / AC-17.5)

    func test_savedWidget_empty_small_light() {
        let view = WidgetCard.SavedEmpty()
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 158, height: 158),
                traits: Self.lightTraits
            ),
            record: .missing
        )
    }

    func test_savedWidget_empty_small_dark() {
        let view = WidgetCard.SavedEmpty()
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 158, height: 158),
                traits: Self.darkTraits
            ),
            record: .missing
        )
    }

    func test_savedWidget_empty_medium_light() {
        let view = WidgetCard.SavedEmpty()
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 338, height: 158),
                traits: Self.lightTraits
            ),
            record: .missing
        )
    }

    func test_savedWidget_empty_medium_dark() {
        let view = WidgetCard.SavedEmpty()
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 338, height: 158),
                traits: Self.darkTraits
            ),
            record: .missing
        )
    }
}
#endif

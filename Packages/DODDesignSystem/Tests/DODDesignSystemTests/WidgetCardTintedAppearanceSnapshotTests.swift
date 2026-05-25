#if canImport(UIKit) && canImport(WidgetKit)
import SnapshotTesting
import SwiftUI
import UIKit
import WidgetKit
import XCTest

@testable import DODDesignSystem

/// L4 visual-regression tests for the iOS 18+ home-screen "Tinted" /
/// "Vibrant" widget rendering modes (US-23, AC-23.3).
///
/// Apple's WidgetKit pipeline hands the active home-screen appearance
/// to the widget extension as a `WidgetRenderingMode` environment
/// value (`.fullColor`, `.accented`, `.vibrant`). The existing
/// `DesignSystemSnapshotTests.test_widgetCard_*` baselines pin the
/// `.fullColor` (Standard) rendering; the dark-mode pair in
/// `SnapshotTests+AppearanceAudit.swift` pins the Standard-dark
/// rendering. This file fills the missing two rendering-mode cells
/// (`.accented` and `.vibrant`) by injecting the env value on a
/// SwiftUI host.
///
/// **Why a separate file:** keeps the iOS 18+ availability guards
/// localised (the parent class is annotated `@available(iOS 18.0, *)`
/// so individual tests don't have to). Also keeps `SnapshotTests.swift`
/// under SwiftLint's file-length cap — same separation rationale as
/// `SnapshotTests+AppearanceAudit.swift` and `SavedWidgetSnapshotTests.swift`.
///
/// **Why `WidgetCard.Hero` renders as a gradient placeholder in these
/// baselines:** the snapshot harness has no easy way to inject a real
/// image fixture into the `AsyncImage` inside `WidgetCard.Hero` without
/// adding a test-only image provider injection point. The `heroImageURL:
/// nil` path is what the production widget extension renders when the
/// snapshot's `heroImageFilename` is nil OR when the App Group container
/// can't be located (e.g. during the gallery preview before the host
/// has had a chance to write any snapshot). That's also what
/// `T-360`'s populated-state baselines render under — same gradient
/// fallback. The Tinted/Vibrant pass is what we're auditing, not the
/// image-bridge integration.
///
/// **`record: .missing`** matches the surrounding US-9 / US-17 widget
/// tests — first iOS sim run lays down baselines, subsequent runs
/// diff. PNGs land under `__Snapshots__/WidgetCardTintedAppearanceSnapshotTests/`.
///
/// Spec trace: spec.md US-23, AC-23.1 (matrix coverage), AC-23.3
/// (Tinted/Vibrant baseline regression net).
@available(iOS 18.0, *)
final class WidgetCardTintedAppearanceSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    // MARK: - Featured widget (US-9 / US-21)

    func test_widgetCard_small_populated_tinted() {
        let view = WidgetCard.Small(content: Self.widgetContent())
            .environment(\.widgetRenderingMode, .accented)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 158, height: 158)),
            record: .missing
        )
    }

    func test_widgetCard_small_populated_vibrant() {
        let view = WidgetCard.Small(content: Self.widgetContent())
            .environment(\.widgetRenderingMode, .vibrant)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 158, height: 158)),
            record: .missing
        )
    }

    func test_widgetCard_medium_populated_tinted() {
        let view = WidgetCard.Medium(content: Self.widgetContent())
            .environment(\.widgetRenderingMode, .accented)
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 338, height: 158)),
            record: .missing
        )
    }

    func test_widgetCard_medium_populated_vibrant() {
        let view = WidgetCard.Medium(content: Self.widgetContent())
            .environment(\.widgetRenderingMode, .vibrant)
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 338, height: 158)),
            record: .missing
        )
    }

    func test_widgetCard_placeholder_tinted() {
        let view = WidgetCard.Placeholder()
            .environment(\.widgetRenderingMode, .accented)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 158, height: 158)),
            record: .missing
        )
    }

    func test_widgetCard_placeholder_vibrant() {
        let view = WidgetCard.Placeholder()
            .environment(\.widgetRenderingMode, .vibrant)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 158, height: 158)),
            record: .missing
        )
    }

    // MARK: - Saved-recipes widget (US-17)

    func test_savedWidget_small_oneEntry_tinted() {
        let view = WidgetCard.SavedSmall(row: Self.savedSampleRow)
            .environment(\.widgetRenderingMode, .accented)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 158, height: 158)),
            record: .missing
        )
    }

    func test_savedWidget_small_oneEntry_vibrant() {
        let view = WidgetCard.SavedSmall(row: Self.savedSampleRow)
            .environment(\.widgetRenderingMode, .vibrant)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 158, height: 158)),
            record: .missing
        )
    }

    func test_savedWidget_medium_threeEntries_tinted() {
        let view = WidgetCard.SavedMedium(rows: Self.savedSampleRows)
            .environment(\.widgetRenderingMode, .accented)
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 338, height: 158)),
            record: .missing
        )
    }

    func test_savedWidget_medium_threeEntries_vibrant() {
        let view = WidgetCard.SavedMedium(rows: Self.savedSampleRows)
            .environment(\.widgetRenderingMode, .vibrant)
            .frame(width: 338, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 338, height: 158)),
            record: .missing
        )
    }

    func test_savedWidget_empty_small_tinted() {
        let view = WidgetCard.SavedEmpty()
            .environment(\.widgetRenderingMode, .accented)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 158, height: 158)),
            record: .missing
        )
    }

    func test_savedWidget_empty_small_vibrant() {
        let view = WidgetCard.SavedEmpty()
            .environment(\.widgetRenderingMode, .vibrant)
            .frame(width: 158, height: 158)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 158, height: 158)),
            record: .missing
        )
    }

    // MARK: - Fixture helpers (mirror the SnapshotTests fixtures)

    private static func widgetContent() -> WidgetCard.Content {
        WidgetCard.Content(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
    }

    private static let savedSampleRow = WidgetCard.SavedRow(
        title: "Garlic Butter Skillet Corn",
        heroImageURL: nil
    )

    private static let savedSampleRows: [WidgetCard.SavedRow] = [
        WidgetCard.SavedRow(title: "Garlic Butter Skillet Corn"),
        WidgetCard.SavedRow(title: "Sourdough Bread"),
        WidgetCard.SavedRow(title: "Cast Iron Pizza"),
    ]
}
#endif

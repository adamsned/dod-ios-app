#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// L4 visual-regression tests for the lock-screen widget (US-22).
///
/// Three baselines: populated, populated-with-long-title (truncation
/// check), and empty. Lock-screen widgets render text-only and the
/// system applies the monochrome wallpaper-aware tint at present-time
/// (`vibrant` rendering mode is the iOS default for accessory family
/// widgets) — so a single rendering pass per state is the L4 baseline.
/// Unlike the home-screen `SavedWidgetSnapshotTests`, we do not record
/// light + dark variants: the lock-screen rendering pipeline does not
/// differentiate by `userInterfaceStyle` the way the home-screen one
/// does, and pretending it does would produce two identical PNGs per
/// state. `record: .missing` matches the surrounding widget snapshot
/// tests — first run lays down baselines, subsequent runs diff.
///
/// Lives in its own file alongside `SavedWidgetSnapshotTests.swift` to
/// keep the parent `SnapshotTests.swift` under SwiftLint's 400-line
/// file-length warning cap (it's already at 365 lines).
///
/// Spec trace: spec.md US-22, AC-22.5, REG-22.
final class LockScreenWidgetSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an
        // intentional visual change, then revert before commit.
        isRecording = false
    }

    // MARK: - Fixtures

    /// Apple-documented `.accessoryRectangular` system widget size on
    /// iPhone is ~172×76pt. Using a fixed layout keeps the tests
    /// hermetic — we are testing the layout primitive, not WidgetKit's
    /// system chrome around it.
    private static let lockScreenSize = CGSize(width: 172, height: 76)

    private static let sampleContent = WidgetCard.LockScreenContent(
        title: "Garlic Butter Skillet Corn",
        excerpt: "An easy 15-minute side dish that pairs with everything."
    )

    /// Long-enough title to exercise the 2-line cap + the truncation
    /// behaviour the `.lineLimit(2)` modifier provides. Excerpt is
    /// longer than will fit on one line so the `.lineLimit(1)` cap is
    /// also exercised.
    private static let longTitleContent = WidgetCard.LockScreenContent(
        title: "Slow-Roasted Bourbon Berry Cheesecake with Maple Glaze",
        excerpt: "A weekend project worth every minute in the oven and on the cooling rack."
    )

    // MARK: - Populated

    /// AC-22.2: title + short description render as text only. No
    /// image, no chip. Single rendering pass per CL-37 (text-only,
    /// monochrome at present-time).
    func test_lockScreenWidget_rectangular_populated() {
        let view = WidgetCard.LockScreenRectangular(content: Self.sampleContent)
            .frame(width: Self.lockScreenSize.width, height: Self.lockScreenSize.height)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: Self.lockScreenSize.width, height: Self.lockScreenSize.height)
            ),
            record: .missing
        )
    }

    /// AC-22.2: long titles truncate cleanly to 2 lines and the
    /// excerpt truncates to 1 line. Pinning this state guards against
    /// a future "let it overflow" change accidentally drawing past the
    /// system-allotted rectangular frame.
    func test_lockScreenWidget_rectangular_populated_longTitle() {
        let view = WidgetCard.LockScreenRectangular(content: Self.longTitleContent)
            .frame(width: Self.lockScreenSize.width, height: Self.lockScreenSize.height)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: Self.lockScreenSize.width, height: Self.lockScreenSize.height)
            ),
            record: .missing
        )
    }

    // MARK: - Empty (CL-37 / AC-22.4)

    /// AC-22.4: when no snapshot exists (first launch / App Group
    /// missing / version mismatch), the widget renders placeholder
    /// copy ("Dutch Oven Daddy" + "Open the app to see the latest
    /// recipe.") that tap-targets to `dod://feed`. Tap-target wiring
    /// is verified by the entry view's `widgetURL(_:)` setup rather
    /// than by this snapshot — this test pins the visual layer only.
    func test_lockScreenWidget_rectangular_empty() {
        let view = WidgetCard.LockScreenEmpty()
            .frame(width: Self.lockScreenSize.width, height: Self.lockScreenSize.height)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: Self.lockScreenSize.width, height: Self.lockScreenSize.height)
            ),
            record: .missing
        )
    }
}
#endif

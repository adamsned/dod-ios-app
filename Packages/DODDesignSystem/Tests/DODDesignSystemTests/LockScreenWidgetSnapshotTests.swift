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

    /// Apple-documented `.accessoryCircular` system widget size on iPhone is
    /// ~76×76pt. Fixed layout keeps the test hermetic — we render the glyph
    /// primitive, not WidgetKit's circular chrome around it.
    private static let circularSize = CGSize(width: 76, height: 76)

    private static let sampleContent = WidgetCard.LockScreenContent(
        eyebrow: "Latest Recipe",
        title: "Garlic Butter Skillet Corn"
    )

    /// Long-enough title to exercise the DUT-451 3-line cap + truncation
    /// (`.lineLimit(3)`). No excerpt any more — the title owns the card.
    private static let longTitleContent = WidgetCard.LockScreenContent(
        eyebrow: "Latest Recipe",
        title: "Slow-Roasted Bourbon Berry Cheesecake with Maple Glaze and Toasted Pecans"
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

    /// DUT-460 — the adaptive "Latest Article" eyebrow on the lock-screen face.
    func test_lockScreenWidget_rectangular_article() {
        let view = WidgetCard.LockScreenRectangular(
            content: .init(
                eyebrow: "Latest Article",
                title: "Seasoning Cast Iron: The Only Guide You Need"
            )
        )
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

    // MARK: - Circular Saved shortcut (CL-168 / AC-22.7)

    /// AC-22.7: the `.accessoryCircular` Saved shortcut renders the
    /// `bookmark.fill` glyph. The tap target (`dod://saved`) is wired by the
    /// `SavedLockScreenWidget` entry view's `widgetURL(_:)`; this pins the
    /// glyph visual only (the `AccessoryWidgetBackground` disc + the system
    /// monochrome tint are present-time chrome, not part of this primitive).
    func test_lockScreenWidget_circularBookmark() {
        let view = WidgetCard.LockScreenCircularBookmark()
            .frame(width: Self.circularSize.width, height: Self.circularSize.height)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: Self.circularSize.width, height: Self.circularSize.height)
            ),
            record: .missing
        )
    }

    /// DUT-453: the Saved bookmark badged with the saved count. The count is
    /// knocked out of the filled glyph (`.destinationOut`), so this pins that
    /// the number reads as negative space rather than same-tint-on-tint.
    func test_lockScreenWidget_circularBookmark_withCount() {
        let view = WidgetCard.LockScreenCircularBookmark(count: 12)
            .frame(width: Self.circularSize.width, height: Self.circularSize.height)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.97,
                layout: .fixed(width: Self.circularSize.width, height: Self.circularSize.height)
            ),
            record: .missing
        )
    }
}
#endif

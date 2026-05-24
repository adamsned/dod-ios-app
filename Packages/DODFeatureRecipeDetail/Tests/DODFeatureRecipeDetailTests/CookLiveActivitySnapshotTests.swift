#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODFeatureRecipeDetail

/// L4 visual-regression tests for the Cook Mode Live Activity surfaces
/// (US-11).
///
/// The widget extension itself cannot be imported into a test target, so
/// the views are extracted into ``CookActivityLockScreenView`` and the
/// Dynamic Island compact pieces live as plain SwiftUI views in the
/// feature package. Both the extension and these tests render the same
/// types — the snapshot baselines guarantee the on-glass layout doesn't
/// drift away from what the `ActivityConfiguration` will hand to iOS.
///
/// Spec trace: constitution §6 L4, US-11 AC-11.1..AC-11.4.
final class CookLiveActivitySnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an intentional
        // visual change, then revert before commit.
        isRecording = false
    }

    func test_lockScreen_running() {
        let view = CookActivityLockScreenView(
            recipeTitle: "Dutch Oven Pot Roast",
            stepText: "Cover and braise for 2 hours, basting every 30 min.",
            remainingSeconds: 900,
            totalSeconds: 1_800,
            isPaused: false
        )
        .frame(width: 360, height: 140)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 360, height: 140)))
    }

    func test_lockScreen_paused() {
        let view = CookActivityLockScreenView(
            recipeTitle: "Dutch Oven Pot Roast",
            stepText: "Rest before slicing.",
            remainingSeconds: 480,
            totalSeconds: 900,
            isPaused: true
        )
        .frame(width: 360, height: 140)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 360, height: 140)))
    }

    func test_lockScreen_lastSeconds() {
        // Visual: the progress arc should be nearly full, the countdown
        // small enough to still fit two digits.
        let view = CookActivityLockScreenView(
            recipeTitle: "Skillet Cornbread",
            stepText: "Bake until edges are golden.",
            remainingSeconds: 12,
            totalSeconds: 1_200,
            isPaused: false
        )
        .frame(width: 360, height: 140)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 360, height: 140)))
    }

    func test_dynamicIsland_compactLeading() {
        let view = CookActivityCompactLeadingView()
            .frame(width: 30, height: 30)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 30, height: 30)))
    }

    func test_dynamicIsland_compactTrailing() {
        let view = CookActivityCompactTrailingView(remainingSeconds: 75)
            .frame(width: 60, height: 30)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 60, height: 30)))
    }
}
#endif

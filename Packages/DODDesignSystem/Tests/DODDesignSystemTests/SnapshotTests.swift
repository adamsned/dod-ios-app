#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// L4 visual-regression tests for DesignSystem components.
///
/// First run with `record: true` creates baseline PNGs under
/// `__Snapshots__/`. Subsequent runs diff against those baselines and fail
/// with a pixel diff if anything moves. Intentional visual changes are
/// approved by re-recording and committing the new PNGs.
///
/// Spec trace: constitution §6 L4, AC-T1 ("PR runs L4").
final class DesignSystemSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an intentional
        // visual change, then revert before commit.
        isRecording = false
    }

    func test_emptyState_default() {
        let view = EmptyState(title: "No saved recipes yet", message: "Tap the heart on any recipe.")
            .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 600)))
    }

    func test_emptyState_withAction() {
        let view = EmptyState(
            title: "You need internet",
            message: "Connect to load recipes.",
            action: .init(title: "Retry") {}
        )
        .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 600)))
    }

    func test_offlineBanner_offline() {
        let view = OfflineBanner(isOffline: true)
            .frame(width: 390, height: 60)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 60)))
    }

    func test_snackbar_plain() {
        let view = Snackbar(message: "Recipe unavailable.")
            .frame(width: 390, height: 80)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 80)))
    }

    func test_snackbar_withUndo() {
        let view = Snackbar(message: "Removed from saved.", action: .init(title: "Undo") {})
            .frame(width: 390, height: 80)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 80)))
    }

    func test_recipeCard_full() {
        let view = RecipeCard(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
        .frame(width: 358)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    func test_recipeCard_noTimeChip() {
        let view = RecipeCard(
            title: "Sourdough Bread",
            excerpt: "Crusty, chewy, slow-fermented.",
            heroImageURL: nil
        )
        .frame(width: 358)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    /// US-8 first-launch welcome sheet. iPhone 17 logical size is 402×874pt;
    /// rendering at .large detent fills (nearly) the full screen and gives
    /// us a stable baseline to diff against on layout changes.
    func test_onboardingSheet_default() {
        let view = OnboardingSheet(
            title: "Welcome to Dutch Oven Daddy",
            bullets: [
                .init(
                    systemImage: "house.fill",
                    title: "Browse the latest",
                    caption: "New cast iron recipes appear at the top."
                ),
                .init(
                    systemImage: "magnifyingglass",
                    title: "Search what you've got",
                    caption: "Type any ingredient or technique to filter."
                ),
                .init(
                    systemImage: "heart.fill",
                    title: "Save for offline",
                    caption: "Tap the heart on any recipe to cook it without Wi-Fi."
                ),
            ],
            ctaTitle: "Get cooking",
            onContinue: {}
        )
        .frame(width: 402, height: 874)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 402, height: 874)))
    }
}
#endif

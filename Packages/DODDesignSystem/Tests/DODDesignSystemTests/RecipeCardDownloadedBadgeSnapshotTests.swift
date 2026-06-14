#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// T-774 / DUT-80 — visual baseline for the Saved-tab "Downloaded" badge.
/// `RecipeCard(isDownloaded: true)` overlays a burnt-orange "Downloaded"
/// capsule on the LEADING edge of the hero (the time chip sits on the
/// trailing edge). The half-width frame matches the Saved tab's 2-column grid
/// and confirms the two chips don't collide. Lives in its own file (per the
/// repo's per-theme snapshot split) so `SnapshotTests.swift` stays under
/// SwiftLint's 400-line cap. `record: .missing` lays the PNG down on the
/// first iPhone-sim run; subsequent runs diff.
final class RecipeCardDownloadedBadgeSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    func test_recipeCard_downloadedBadge_halfWidth() {
        let view = RecipeCard(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min",
            isDownloaded: true
        )
        .frame(width: 180)
        assertSnapshot(
            of: view,
            as: .image(precision: 0.98, perceptualPrecision: 0.97, layout: .sizeThatFits),
            record: .missing
        )
    }
}
#endif

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// T-845 / DUT-262 — guards the gallery card's DYNAMIC excerpt. At the
/// half-width grid size a SHORT title (1 line) frees vertical space, so the
/// excerpt fills MORE lines (3 here) instead of being pinned to 2 — while the
/// card stays the SAME total height as a 2-line-title card (the constant-height
/// contract from DUT-260 / T-839). Without this fixture nothing distinguishes
/// the `ViewThatFits` excerpt from a regression back to `lineLimit(2,
/// reservesSpace: true)` (a 2-line-title card looks identical either way; only a
/// 1-line title reveals the difference). Lives in its own file per the repo's
/// per-theme snapshot split so `SnapshotTests.swift` stays under the cap.
/// `record: .missing` lays the PNG down on the first iPhone-17-sim run.
final class RecipeCardExcerptSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    func test_recipeCard_shortTitleHalfWidth() {
        let view = RecipeCard(
            title: "Cornbread",
            excerpt:
                "A cast-iron skillet classic with a crisp golden crust and a tender, "
                + "buttery crumb that soaks up every bit of honey you serve with it.",
            heroImageURL: nil,
            totalTimeDisplay: "30 min"
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

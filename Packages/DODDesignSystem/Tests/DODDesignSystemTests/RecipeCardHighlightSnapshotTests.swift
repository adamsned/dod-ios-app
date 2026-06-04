#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// DUT-10 — visual baselines for search-term highlighting. Matched query
/// terms in a result title render in the brand accent (`DODColor.accent`);
/// the rest of the title keeps `DODColor.label`. Pins both the gallery card
/// and the dense list-row variant with the same multi-token query.
final class RecipeCardHighlightSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    /// Gallery card — "Skillet" and "Corn" tinted by the query "skillet corn".
    func test_recipeCard_highlightedTitle() {
        let view = RecipeCard(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min",
            highlightQuery: "skillet corn"
        )
        .frame(width: 358)
        assertSnapshot(
            of: view,
            as: .image(precision: 0.98, perceptualPrecision: 0.97, layout: .sizeThatFits),
            record: .missing
        )
    }

    /// List-row variant — same highlighted title in the dense layout.
    func test_recipeCard_listRow_highlightedTitle() {
        let view = RecipeCard.ListRow(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min",
            highlightQuery: "skillet corn"
        )
        .frame(width: 358)
        assertSnapshot(
            of: view,
            as: .image(precision: 0.98, perceptualPrecision: 0.97, layout: .sizeThatFits),
            record: .missing
        )
    }
}
#endif

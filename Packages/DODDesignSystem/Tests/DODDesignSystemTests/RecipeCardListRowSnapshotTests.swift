#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// US-38 / AC-38.4 / CL-64 (T-650, 2026-05-27) — visual baselines for
/// `RecipeCard.ListRow`, the dense single-column row variant introduced
/// alongside the gallery-card body for the layout toggle.
///
/// Split into its own file from `SnapshotTests.swift` to keep that
/// file under SwiftLint's 400-line cap (the parent file overran on the
/// T-650 PR — the `RecipeCard.ListRow` baselines live here for the same
/// reason `FlowLayout` and `IdleSuggestionsView` split out of
/// `SearchView.swift`).
final class RecipeCardListRowSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    /// AC-38.4 — list-row variant with the time chip. Pins the 60pt
    /// thumbnail + title (1-line) + excerpt (1-line) + trailing chip
    /// layout.
    func test_recipeCard_listRow_full() {
        let view = RecipeCard.ListRow(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
        .frame(width: 358)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits), record: .missing)
    }

    /// AC-38.4 — list-row variant without the time chip. Verifies the
    /// trailing chip is suppressed entirely when `totalTimeDisplay` is
    /// nil (no empty space, no placeholder).
    func test_recipeCard_listRow_noTimeChip() {
        let view = RecipeCard.ListRow(
            title: "Sourdough Bread",
            excerpt: "Crusty, chewy, slow-fermented.",
            heroImageURL: nil
        )
        .frame(width: 358)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits), record: .missing)
    }
}
#endif

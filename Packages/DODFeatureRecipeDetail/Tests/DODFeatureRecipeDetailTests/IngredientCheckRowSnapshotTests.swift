#if canImport(UIKit)
import DODDomain
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODFeatureRecipeDetail

/// L4 visual-regression coverage for ``IngredientCheckRow``.
///
/// Tests the row's behavior at large text sizes, ensuring it reflows and scales
/// appropriately. First run with `isRecording = false` to create baselines,
/// then revert and commit. Subsequent runs diff against the baselines.
///
/// Spec trace: DUT-118 part 3.
final class IngredientCheckRowSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an intentional
        // visual change, then revert before commit.
        isRecording = false
    }

    @MainActor
    func test_row_rendersAtAccessibility5() {
        let ingredient = RecipeIngredient(text: "1 1/2 cups all-purpose flour, sifted")

        let view = IngredientCheckRow(
            ingredient: ingredient,
            displayText: "1 1/2 cups all-purpose flour, sifted",
            isChecked: false,
            onToggle: {}
        )
        .frame(width: 390)
        .environment(\.dynamicTypeSize, .accessibility5)

        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }
}
#endif

#if canImport(UIKit)
import DODDomain
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODFeatureRecipeDetail

/// L4 visual-regression coverage for ``CookModeStepIndicator``.
///
/// These tests pin the contract that the step indicator renders correctly
/// across different dynamic type sizes, particularly ensuring proper layout
/// for accessibility sizes.
///
/// First run with `isRecording = false` to create baselines, then revert
/// and commit. Subsequent runs diff against the baselines.
///
/// Spec trace: DUT-118, DUT-1581.
final class CookModeStepIndicatorSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an intentional
        // visual change, then revert before commit.
        isRecording = false
    }

    @MainActor
    func test_indicator_renders_with_accessibility5() {
        let viewModel = CookModeViewModel(
            recipe: RecipeDetailTestFixtures.makeRecipe(id: 1001, withDetail: true),
            initialCheckedIngredients: []
        )

        // Simulate being on step 2 of 5
        viewModel.currentStepIndex = 1
        viewModel.stepCount = 5

        let view = CookModeStepIndicator(viewModel: viewModel)
            .frame(width: 390)
            .environment(\.dynamicTypeSize, .accessibility5)

        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    @MainActor
    func test_indicator_renders_finished_with_accessibility5() {
        let viewModel = CookModeViewModel(
            recipe: RecipeDetailTestFixtures.makeRecipe(id: 1002, withDetail: true),
            initialCheckedIngredients: []
        )

        // Simulate being finished
        viewModel.isFinished = true

        let view = CookModeStepIndicator(viewModel: viewModel)
            .frame(width: 390)
            .environment(\.dynamicTypeSize, .accessibility5)

        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }
}
#endif

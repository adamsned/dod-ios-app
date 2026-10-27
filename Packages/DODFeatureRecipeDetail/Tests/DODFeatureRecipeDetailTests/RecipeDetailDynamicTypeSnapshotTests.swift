#if canImport(UIKit)
import DODDomain
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODFeatureRecipeDetail

/// L4 visual-regression coverage at the largest accessibility Dynamic Type
/// size (`.accessibility5`) for Recipe Detail subviews.
///
/// Spec trace: DUT-118 part 5.
final class RecipeDetailDynamicTypeSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to record baselines on an iOS 26.0 simulator
        // (CI runs iOS 26.0.1), then set it back to false before commit.
        isRecording = false
    }

    @MainActor
    func test_ratingsSection_accessibility5() async {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 902, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 902, average: 4.5, count: 27)
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 11, postID: 902, body: "Made it twice — perfect."),
            RecipeDetailTestFixtures.makeComment(id: 12, postID: 902, body: "Family hit."),
        ]
        let viewModel = RecipeDetailRatingsViewSnapshotTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 902
        )
        await viewModel.onAppear()

        let view = RecipeDetailRatingsSection(viewModel: viewModel)
            .frame(width: 390)
            .environment(\.dynamicTypeSize, .accessibility5)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    @MainActor
    func test_infoCard_accessibility5() async {
        let model = RecipeInfoCard.Model(
            prepTime: "15 min",
            cookTime: "1 hr 30 min",
            totalTime: "1 hr 45 min",
            course: "Main Course",
            cuisine: "American",
            diet: "Gluten Free",
            servings: "6",
            calories: "450 kcal",
            author: "Dutch Oven Daddy"
        )

        let view = RecipeInfoCard(model: model)
            .frame(width: 390)
            .environment(\.dynamicTypeSize, .accessibility5)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }
}
#endif

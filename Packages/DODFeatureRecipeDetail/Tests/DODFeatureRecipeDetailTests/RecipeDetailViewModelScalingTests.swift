import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the US-31 / T-440 recipe-scaling view-model surface
/// (AC-31.1..AC-31.8). Lives in its own file to keep
/// `RecipeDetailViewModelTests.swift` under the SwiftLint file-length cap.
@MainActor
@Suite("RecipeDetailViewModel scaling (US-31 / T-440)") struct RecipeDetailViewModelScalingTests {

    @Test func defaultUserServingsFallsBackBeforeRecipeLoads() {
        let dependencies = FakeRecipeDetailDependencies()
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 401)
        // Recipe hasn't loaded — sourceServings defaults to the fallback,
        // userServings sits at the same fallback, factor is 1.0 (no scale).
        #expect(viewModel.sourceServings == RecipeDetailViewModel.defaultServings)
        #expect(viewModel.userServings == RecipeDetailViewModel.defaultServings)
        #expect(viewModel.servingsScaleFactor == 1.0)
    }

    @Test func resetServingsToSourceSyncsToRecipeYield() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 402,
            withDetail: true,
            servings: 6
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 402)
        await viewModel.onAppear()
        viewModel.resetServingsToSourceIfFirstLoad()
        #expect(viewModel.userServings == 6)
        #expect(viewModel.servingsScaleFactor == 1.0)
    }

    @Test func resetServingsIsNoOpAfterManualChange() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 403,
            withDetail: true,
            servings: 6
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 403)
        await viewModel.onAppear()
        viewModel.resetServingsToSourceIfFirstLoad()  // userServings → 6
        viewModel.setUserServings(8)
        viewModel.resetServingsToSourceIfFirstLoad()  // must NOT clobber 8
        #expect(viewModel.userServings == 8)
    }

    @Test func setUserServingsClampsToRange() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 404,
            withDetail: true,
            servings: 4
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 404)
        await viewModel.onAppear()
        viewModel.setUserServings(0)
        #expect(viewModel.userServings == 1)  // lower bound
        viewModel.setUserServings(100)
        #expect(viewModel.userServings == 24)  // upper bound
    }

    @Test func scaleFactorDoublesAtHalfTheServings() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 405,
            withDetail: true,
            servings: 4
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 405)
        await viewModel.onAppear()
        viewModel.resetServingsToSourceIfFirstLoad()
        viewModel.setUserServings(8)
        #expect(viewModel.servingsScaleFactor == 2.0)
    }

    @Test func warningKicksInPastTwelveServings() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 406,
            withDetail: true,
            servings: 4
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 406)
        await viewModel.onAppear()
        viewModel.setUserServings(12)
        #expect(viewModel.shouldShowServingWarning == false)
        viewModel.setUserServings(13)
        #expect(viewModel.shouldShowServingWarning == true)
    }

    /// AC-31.7: a serving-count change must NOT clear the ingredient
    /// check set — the user's in-progress checks survive a scale.
    @Test func scalingPreservesIngredientCheckState() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 407,
            withDetail: true,
            servings: 4
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 407)
        await viewModel.onAppear()
        let firstID = try #require(viewModel.recipe?.ingredients.first?.id)
        viewModel.toggleIngredient(firstID)
        #expect(viewModel.checkedIngredientIDs.contains(firstID))
        viewModel.setUserServings(8)
        #expect(viewModel.checkedIngredientIDs.contains(firstID))
        viewModel.setUserServings(16)
        #expect(viewModel.checkedIngredientIDs.contains(firstID))
    }

    /// AC-31.8: scaling is pure presentation — source `Recipe.servings`
    /// and `RecipeIngredient.text` are never mutated.
    @Test func scalingNeverMutatesSourceRecipe() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        let originalIngredients: [RecipeIngredient] = [
            .init(text: "½ cup flour"),
            .init(text: "1 tablespoon salt"),
        ]
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 408,
            withDetail: true,
            servings: 4,
            ingredients: originalIngredients
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 408)
        await viewModel.onAppear()
        viewModel.setUserServings(16)
        // Source model is untouched — scaling lives in the view layer.
        #expect(viewModel.recipe?.servings == 4)
        #expect(viewModel.recipe?.ingredients[0].text == "½ cup flour")
        #expect(viewModel.recipe?.ingredients[1].text == "1 tablespoon salt")
    }

    // MARK: - Helpers

    static func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/")
                ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }
}

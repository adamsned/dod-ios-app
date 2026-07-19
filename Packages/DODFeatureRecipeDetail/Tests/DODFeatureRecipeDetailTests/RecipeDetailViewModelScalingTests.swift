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

    /// DUT-471 — if the FIRST `.ready` fires before the yield hydrates (the
    /// list-item path, sourceServings == default), the one-shot is spent but the
    /// baseline must still be recorded, so the DUT-315 resync fires when the
    /// real yield later lands. Without the fix, `lastSyncedSourceServings`
    /// stayed nil, the resync deferred forever, and ingredients scaled at
    /// default/N.
    @Test func firstLoadAtDefaultYieldStillResyncsWhenRealYieldArrives() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 410,
            withDetail: true,
            servings: 8
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 410)

        // First `.ready` before the detail loads — sourceServings is the default.
        #expect(viewModel.sourceServings == RecipeDetailViewModel.defaultServings)
        viewModel.resetServingsToSourceIfFirstLoad()  // spends the one-shot at the default

        // Full detail lands the real yield; the resync must now sync the stepper.
        await viewModel.onAppear()
        #expect(viewModel.sourceServings == 8)
        viewModel.resyncServingsIfSourceYieldChanged()
        #expect(viewModel.userServings == 8)
        #expect(viewModel.servingsScaleFactor == 1.0)
    }

    /// DUT-677 — a recipe whose REAL `recipeYield` is 4 (identical to
    /// ``defaultServings``) must still sync the stepper to the source yield on
    /// first load. The old guard (`sourceServings != Self.defaultServings`)
    /// collided the genuine yield with the not-yet-parsed sentinel and skipped
    /// the sync, so a stale/manual `userServings` was never reset back to the
    /// real source yield → ingredients silently scaled at the wrong factor.
    @Test func firstLoadSyncsGenuineYieldOfFourAfterStaleValue() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 411,
            withDetail: true,
            servings: 4
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 411)
        await viewModel.onAppear()

        // Real parsed yield is genuinely 4 — NOT the unparsed sentinel.
        #expect(viewModel.sourceServings == 4)
        #expect(viewModel.recipe?.servings == 4)

        // A stale serving count sits on the stepper before the one-shot fires.
        viewModel.setUserServings(9)
        #expect(viewModel.userServings == 9)

        // First-load sync must reset the stepper to the genuine source yield.
        // Pre-fix the guard bailed because 4 == defaultServings, leaving the
        // stepper stuck at 9 and scaling ingredients at 9/4.
        viewModel.resetServingsToSourceIfFirstLoad()
        #expect(viewModel.userServings == 4)
        #expect(viewModel.servingsScaleFactor == 1.0)
        #expect(viewModel.lastSyncedSourceServings == 4)
    }

    /// DUT-677 regression guard — the true "no parsed yield" (sentinel) case is
    /// preserved: with no recipe loaded, neither resync path clobbers the
    /// stepper (the guards must skip when `recipe?.servings` is nil).
    @Test func noParsedYieldStillSkipsResync() {
        let dependencies = FakeRecipeDetailDependencies()
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 413)
        // Recipe never loaded — sourceServings is the sentinel/default.
        #expect(viewModel.recipe == nil)
        viewModel.setUserServings(7)

        viewModel.resetServingsToSourceIfFirstLoad()  // records baseline, no clamp
        #expect(viewModel.userServings == 7)  // manual value survives

        viewModel.resyncServingsIfSourceYieldChanged()
        #expect(viewModel.userServings == 7)  // still no clobber
    }

    /// Regression: the AC-31.3 default-sync must land `userServings` exactly on
    /// `sourceServings` — even for a large-batch recipe whose yield exceeds the
    /// stepper's own `1...24` UI range (`userServingsRange`, AC-31.2). Before the
    /// fix, `resetServingsToSourceIfFirstLoad()` ran the synced value through
    /// `clampToRange`, so a 30-serving recipe silently landed at
    /// `userServings == 24` on first load and `servingsScaleFactor == 24/30 ==
    /// 0.8` — every ingredient quantity rendered 20% under what the recipe
    /// actually calls for, with zero user interaction. `userServingsRange` is a
    /// UI affordance for the stepper's own +/- taps (`setUserServings`), not a
    /// bound on the default sync.
    @Test func firstLoadDoesNotClampSourceServingsAboveStepperRange() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 420,
            withDetail: true,
            servings: 30
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 420)
        await viewModel.onAppear()
        viewModel.resetServingsToSourceIfFirstLoad()
        #expect(viewModel.sourceServings == 30)
        #expect(viewModel.userServings == 30)  // must NOT clamp to 24
        #expect(viewModel.servingsScaleFactor == 1.0)
    }

    /// Same regression as ``firstLoadDoesNotClampSourceServingsAboveStepperRange``,
    /// but through the DUT-315 resync path (a different, larger-yield recipe
    /// swapped in after the one-shot already fired at the default) rather than
    /// the first-load one-shot itself. `resyncServingsIfSourceYieldChanged()` had
    /// the identical `clampToRange` bug.
    @Test func resyncDoesNotClampSourceServingsAboveStepperRange() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 421,
            withDetail: true,
            servings: 40
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 421)

        // First `.ready` before the detail loads — sourceServings is the default.
        #expect(viewModel.sourceServings == RecipeDetailViewModel.defaultServings)
        viewModel.resetServingsToSourceIfFirstLoad()  // spends the one-shot at the default

        // Full detail lands the real (large) yield; the resync must sync the
        // stepper to it exactly, not clamp it to the 1...24 UI range.
        await viewModel.onAppear()
        #expect(viewModel.sourceServings == 40)
        viewModel.resyncServingsIfSourceYieldChanged()
        #expect(viewModel.userServings == 40)  // must NOT clamp to 24
        #expect(viewModel.servingsScaleFactor == 1.0)
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

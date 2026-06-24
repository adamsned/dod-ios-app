import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-216: the rating-summary load path must not corrupt the cache. The public
/// WPRM aggregate always returns `userRating == nil`, and a fetch failure
/// degrades to a 0/0 summary — so `loadRatingsAndComments()` must (1) carry the
/// device's remembered vote forward across a successful refresh, and (2) never
/// zero a good cached aggregate when the refresh fails / returns empty.
@MainActor
@Suite("RecipeDetail rating cache (DUT-216)") struct RecipeDetailRatingsCacheTests {

    @Test func successfulRefreshPreservesRememberedUserRating() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.cachedRecipes[501] = RecipeDetailTestFixtures.makeRecipe(
            id: 501,
            withDetail: true
        )
        // The device remembers this user voted 4 stars in a prior session.
        dependencies.cachedRatingByRecipe[501] = RecipeRating(
            recipeID: 501,
            average: 4.0,
            count: 5,
            userRating: 4
        )
        // The public aggregate refresh: new counts, but no userRating (the WPRM
        // public summary never returns it).
        dependencies.fetchedRatingSummary = RecipeRating(
            recipeID: 501,
            average: 4.5,
            count: 10,
            userRating: nil
        )
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 501
        )

        await viewModel.onAppear()

        // The refreshed aggregate is adopted...
        #expect(viewModel.ratingSummary?.count == 10)
        #expect(viewModel.ratingSummary?.average == 4.5)
        // ...but the remembered vote survives (it was erased on every open
        // before the fix).
        #expect(viewModel.ratingSummary?.userRating == 4)
        // And the persisted cache keeps both the new aggregate and the vote.
        #expect(dependencies.cachedRatingByRecipe[501]?.userRating == 4)
        #expect(dependencies.cachedRatingByRecipe[501]?.count == 10)
    }

    @Test func failedRefreshKeepsCachedAggregate() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.cachedRecipes[502] = RecipeDetailTestFixtures.makeRecipe(
            id: 502,
            withDetail: true
        )
        dependencies.cachedRatingByRecipe[502] = RecipeRating(
            recipeID: 502,
            average: 4.8,
            count: 37,
            userRating: 5
        )
        // nil -> the Fake returns the 0/0 failure-degrade summary (REG-14).
        dependencies.fetchedRatingSummary = nil
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 502
        )

        await viewModel.onAppear()

        // A transient failure must NOT blank the stars (they were zeroed from
        // the poisoned cache before the fix).
        #expect(viewModel.ratingSummary?.count == 37)
        #expect(viewModel.ratingSummary?.average == 4.8)
        #expect(viewModel.ratingSummary?.userRating == 5)
        // The cache was not overwritten with 0/0.
        #expect(dependencies.cachedRatingByRecipe[502]?.count == 37)
    }
}

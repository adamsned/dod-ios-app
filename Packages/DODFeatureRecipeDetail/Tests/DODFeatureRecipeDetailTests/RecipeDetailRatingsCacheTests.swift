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

    /// DUT-545: a rating POST succeeds but its follow-up summary GET hard-fails,
    /// so `WPRMRatingsClient.postRating` degrades to a SYNTHETIC `count == 1`
    /// aggregate (5.0 / 1) carrying the just-submitted vote. That synthetic
    /// refresh must NOT shrink the real cached "4.2★ (500)" aggregate — the
    /// displayed AND cached average/count stay 4.2/500, while the user's own
    /// vote (5) is still carried forward. Before the fix the good aggregate was
    /// overwritten and cached as 5.0/1, persisting across relaunch.
    @Test func syntheticFailedSummaryRefreshDoesNotClobberRealAggregate() async {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.cachedRatingByRecipe[503] = RecipeRating(
            recipeID: 503,
            average: 4.2,
            count: 500,
            userRating: nil
        )
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 503
        )
        // Seed the on-screen aggregate from the cache (as loadRatingsAndComments would).
        await viewModel.applyRatingRefresh(
            RecipeRating(recipeID: 503, average: 4.2, count: 500, userRating: nil)
        )
        #expect(viewModel.ratingSummary?.count == 500)

        // The synthetic post-failure fallback: count == 1, average == stars,
        // carrying the vote the user just cast.
        await viewModel.applyRatingRefresh(
            RecipeRating(recipeID: 503, average: 5.0, count: 1, userRating: 5)
        )

        // The good aggregate stays put — displayed...
        #expect(viewModel.ratingSummary?.average == 4.2)
        #expect(viewModel.ratingSummary?.count == 500)
        // ...and the user's own vote is still carried forward (not lost).
        #expect(viewModel.ratingSummary?.userRating == 5)
        // ...and the shrink was NOT written to the cache (still 4.2/500).
        #expect(dependencies.cachedRatingByRecipe[503]?.average == 4.2)
        #expect(dependencies.cachedRatingByRecipe[503]?.count == 500)
    }

    /// DUT-545 companion: a genuine subsequent SUCCESSFUL summary GET carries
    /// the full tally (count 501 after the new vote landed) and IS adopted —
    /// the `>= existing count` rule blocks only the non-authoritative synthetic
    /// `1`, never a real refresh.
    @Test func realLargerRefreshIsStillAdoptedAfterAShrinkWasBlocked() async {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.cachedRatingByRecipe[504] = RecipeRating(
            recipeID: 504,
            average: 4.2,
            count: 500,
            userRating: nil
        )
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 504
        )
        await viewModel.applyRatingRefresh(
            RecipeRating(recipeID: 504, average: 4.2, count: 500, userRating: 5)
        )

        // A real, successful aggregate GET: the new vote is now counted (501).
        await viewModel.applyRatingRefresh(
            RecipeRating(recipeID: 504, average: 4.21, count: 501, userRating: nil)
        )

        #expect(viewModel.ratingSummary?.average == 4.21)
        #expect(viewModel.ratingSummary?.count == 501)
        // The remembered vote survives the nil-bearing public GET.
        #expect(viewModel.ratingSummary?.userRating == 5)
        // The real, larger aggregate WAS cached.
        #expect(dependencies.cachedRatingByRecipe[504]?.count == 501)
    }
}

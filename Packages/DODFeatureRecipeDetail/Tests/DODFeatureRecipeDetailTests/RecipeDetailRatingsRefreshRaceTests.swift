import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// A stale in-flight `loadRatingsAndComments()` background refresh must not
/// clobber a fresher rating the user just submitted while that refresh was
/// still pending.
///
/// The ratings section renders the moment `loadRatingsAndComments()` seeds
/// `ratingSummary` from the cache, well before its own network
/// `fetchRatingSummary(recipeID:)` round trip resolves — so a user who taps
/// "Submit rating" quickly enough can have their own `postRating(...)` POST
/// land and apply (via `applyRatingRefresh`) BEFORE that earlier, slower
/// background fetch finishes. Because `applyRatingRefresh` had no way to
/// tell "this incoming aggregate was requested before the one already
/// applied," the stale background response — carrying the PRE-submission
/// average/count — landed last and silently reverted the on-screen (and
/// cached) aggregate to numbers that no longer reflect the user's own
/// just-cast vote.
///
/// Same race class, same fix shape as `FeedViewModel`'s `loadGeneration`
/// (DUT-511 / `FeedViewModelRefreshRaceTests`): a monotonic generation token
/// bumped before every rating-affecting network call and re-checked
/// immediately after that call's `await` returns, so a superseded response
/// is discarded instead of overwriting fresher state.
@MainActor
@Suite("RecipeDetailViewModel rating-refresh vs in-flight submit race")
struct RecipeDetailRatingsRefreshRaceTests {

    @Test func staleBackgroundRefreshDoesNotClobberNewlySubmittedRating() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 601, withDetail: true)
        dependencies.guestIdentity = (name: "Jamie", email: "jamie@example.com")
        // The network aggregate that was already stale by the time it
        // resolves — the pre-submission average/count.
        dependencies.fetchedRatingSummary = RecipeRating(
            recipeID: 601,
            average: 4.0,
            count: 10,
            userRating: nil
        )
        // What the rating POST returns once the vote actually landed — a
        // genuine (non-synthetic; count != 1) aggregate that already
        // includes the new vote.
        dependencies.postedRatingResult = RecipeRating(
            recipeID: 601,
            average: 4.09,
            count: 11,
            userRating: 5
        )

        let resumeRatingFetch = AsyncStream<Void>.makeStream()
        dependencies.fetchRatingSummaryGate = {
            for await _ in resumeRatingFetch.stream { return }
        }

        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 601
        )

        // Start the background rating/comments refresh; it parks on the gate
        // right before `applyRatingRefresh` would run.
        let loadTask = Task { await viewModel.loadRatingsAndComments() }

        // Spin until the background fetch has genuinely started (and is
        // parked on the gate) before racing the submit against it.
        var attempts = 0
        while dependencies.fetchRatingSummaryCallCount == 0, attempts < 500 {
            try await Task.sleep(nanoseconds: 1_000_000)  // 1 ms
            attempts += 1
        }
        #expect(dependencies.fetchRatingSummaryCallCount == 1)

        // While the background refresh is still in flight, the user submits
        // a rating. Its own POST resolves immediately (no gate) and applies
        // its newer aggregate right away.
        await viewModel.submitRating(stars: 5)
        #expect(viewModel.ratingSummary?.count == 11)
        #expect(viewModel.ratingSummary?.average == 4.09)

        // Now release the stale background fetch and let it finish.
        resumeRatingFetch.continuation.yield(())
        resumeRatingFetch.continuation.finish()
        await loadTask.value

        // The stale (pre-submission) aggregate must NOT overwrite the
        // fresher, just-submitted one.
        #expect(
            viewModel.ratingSummary?.count == 11,
            "a stale background refresh must not revert the just-submitted rating count"
        )
        #expect(
            viewModel.ratingSummary?.average == 4.09,
            "a stale background refresh must not revert the just-submitted average"
        )
        #expect(viewModel.ratingSummary?.userRating == 5)
    }

    @Test func normalBackgroundRefreshStillAppliesWithNoConcurrentSubmit() async throws {
        // Control: with no concurrent submit, the ordinary background
        // refresh still applies — the generation guard must not swallow a
        // legitimate, un-superseded response.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 602, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(
            recipeID: 602,
            average: 4.7,
            count: 21,
            userRating: nil
        )
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 602
        )

        await viewModel.loadRatingsAndComments()

        #expect(viewModel.ratingSummary?.count == 21)
        #expect(viewModel.ratingSummary?.average == 4.7)
    }
}

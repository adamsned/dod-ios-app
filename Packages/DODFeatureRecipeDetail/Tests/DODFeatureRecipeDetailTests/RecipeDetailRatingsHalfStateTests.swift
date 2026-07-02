import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-395 — the consolidated rate + comment submit must not leave the user in
/// a silent half-state when the rating POST succeeds but the comment POST then
/// fails. Previously they saw only the bare comment-error snackbar, with no
/// hint their stars actually stuck, so they'd re-rate and re-submit. Split into
/// its own file so `RecipeDetailRatingsConsolidationTests` stays under the
/// SwiftLint `file_length` / `type_body_length` caps.
///
/// Coverage stays at L1/L2 against `FakeRecipeDetailDependencies` — no write
/// reaches the live blog (constitution §6).
@MainActor
@Suite("RecipeDetailViewModel.submitRatingAndComment — DUT-395 half-state")
struct RecipeDetailRatingsHalfStateTests {

    /// The RATING lands but the COMMENT POST then fails: the combined flow must
    /// replace the bare comment-error snackbar with the half-state copy telling
    /// the user the rating saved and only the comment needs a retry, and it must
    /// preserve the draft (so the retry keeps their text).
    @Test func surfacesHalfStateWhenCommentFailsAfterRating() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 817, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
        // The rating POST succeeds…
        dependencies.postedRatingResult = RecipeRating(
            recipeID: 817,
            average: 4.2,
            count: 12,
            userRating: 4
        )
        // …but the comment POST then fails.
        dependencies.postCommentError = WPClientError.httpStatusWithBody(
            503,
            message: "Service unavailable."
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 817)
        await viewModel.onAppear()

        viewModel.setPendingRating(4)
        viewModel.setCommentDraft("Great, but the server hiccuped.")
        await viewModel.submitRatingAndComment()

        // The bare comment-error snackbar is replaced with the half-state copy.
        #expect(
            viewModel.snackbarMessage
                == "Your rating was saved, but the comment didn't post — try again."
        )
        // The rating aggregate reflects the successful rating POST.
        #expect(viewModel.ratingSummary?.userRating == 4)
        // The draft is preserved so the retry keeps the user's text.
        #expect(viewModel.commentDraft == "Great, but the server hiccuped.")
        // The rating DID record; the comment did NOT.
        let rated = dependencies.telemetryEvents.contains { event in
            if case .recipeRated(_, let stars) = event { return stars == 4 }
            return false
        }
        let commented = dependencies.telemetryEvents.contains { event in
            if case .recipeCommentSubmitted = event { return true }
            return false
        }
        #expect(rated, "The rating POST must have landed")
        #expect(commented == false, "The comment POST failed, so no submit event")
    }

    /// Guard rail: when BOTH the rating and the comment fail, the half-state
    /// copy must NOT appear — the comment error owns the snackbar (nothing was
    /// saved, so "your rating was saved" would be a lie).
    @Test func keepsCommentErrorWhenRatingAlsoFailed() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 818, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
        dependencies.postRatingShouldFail = true
        dependencies.postCommentError = WPClientError.httpStatusWithBody(
            503,
            message: "Service unavailable."
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 818)
        await viewModel.onAppear()

        viewModel.setPendingRating(4)
        viewModel.setCommentDraft("Both endpoints are down.")
        await viewModel.submitRatingAndComment()

        // The comment error owns the snackbar — no false "rating saved" claim.
        #expect(viewModel.snackbarMessage?.contains("Your rating was saved") == false)
        #expect(viewModel.snackbarMessage?.contains("503") == true)
    }

    // MARK: - Helpers

    static func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/") ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }
}

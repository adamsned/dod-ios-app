import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-24: the recipe-detail Ratings & Reviews area used to render TWO
/// interactive star controls (a standalone "Submit rating" bar AND the
/// `CommentComposer`'s own "Rate (optional)" stars), each with its own
/// submit. The view layer was consolidated into ONE rate (stars) + optional
/// comment + single Submit surface, driven by the view model's
/// presentation-layer orchestration (``submitRatingAndComment()``) plus the
/// `canSubmitRatingOrComment` / `isSubmittingRatingOrComment` flags.
///
/// These tests pin the orchestration contract so the single Submit button
/// can't silently regress back into two divergent paths. Coverage stays at
/// L1/L2 against `FakeRecipeDetailDependencies` — no write reaches the live
/// blog (constitution §6).
@MainActor
@Suite("RecipeDetailViewModel — DUT-24 consolidated rate + review")
struct RecipeDetailRatingsConsolidationTests {

    // MARK: - Submit gating flags

    /// DUT-28: `canSubmitRatingOrComment` now requires BOTH something to
    /// submit AND a valid on-form identity. These helpers seed a valid
    /// identity so the flag isolates the "has content" half of the rule;
    /// the identity half gets its own cases below.

    @Test func canSubmitIsFalseWhenNoRatingAndNoComment() async throws {
        let viewModel = Self.makeReadyViewModel(id: 800, withValidIdentity: true)
        #expect(viewModel.canSubmitRatingOrComment == false)
    }

    @Test func canSubmitIsTrueWithRatingOnly() async throws {
        let viewModel = Self.makeReadyViewModel(id: 801, withValidIdentity: true)
        viewModel.setPendingRating(4)
        #expect(viewModel.canSubmitRatingOrComment)
    }

    /// DUT-350 — re-rating an existing vote (3★ → 5★) must keep the NEW vote, not
    /// the cached one. The POST result carries the authoritative `userRating`; the
    /// `??` previously preferred the cached value and silently dropped the change.
    @Test func reRatingKeepsTheNewVoteNotTheCachedOne() async {
        let viewModel = Self.makeReadyViewModel(id: 850, withValidIdentity: true)
        // A cached prior vote of 3★.
        await viewModel.applyRatingRefresh(
            RecipeRating(recipeID: 850, average: 4.0, count: 10, userRating: 3)
        )
        #expect(viewModel.ratingSummary?.userRating == 3)
        // User re-rates to 5★; postRating returns the authoritative userRating = 5.
        await viewModel.applyRatingRefresh(
            RecipeRating(recipeID: 850, average: 4.1, count: 11, userRating: 5)
        )
        #expect(viewModel.ratingSummary?.userRating == 5)
    }

    @Test func canSubmitIsTrueWithCommentOnly() async throws {
        let viewModel = Self.makeReadyViewModel(id: 802, withValidIdentity: true)
        viewModel.setCommentDraft("Great recipe.")
        #expect(viewModel.canSubmitRatingOrComment)
    }

    @Test func canSubmitIsFalseWithWhitespaceOnlyComment() async throws {
        let viewModel = Self.makeReadyViewModel(id: 803, withValidIdentity: true)
        viewModel.setCommentDraft("   \n ")
        #expect(viewModel.canSubmitRatingOrComment == false)
    }

    // MARK: - Submit gating on the on-form identity (DUT-28)

    /// Content present but no identity → Submit stays disabled (we never fire
    /// a POST with a blank author).
    @Test func canSubmitIsFalseWithContentButNoIdentity() async throws {
        let viewModel = Self.makeReadyViewModel(id: 804)
        viewModel.setCommentDraft("Great recipe.")
        #expect(viewModel.isAuthorIdentityValid == false)
        #expect(viewModel.canSubmitRatingOrComment == false)
    }

    /// Content present, name valid but email malformed → still disabled, and
    /// the per-field flags pinpoint which field is wrong.
    @Test func canSubmitIsFalseWithInvalidEmail() async throws {
        let viewModel = Self.makeReadyViewModel(id: 805)
        viewModel.setCommentAuthorName("Jamie")
        viewModel.setCommentAuthorEmail("not-an-email")
        viewModel.setPendingRating(5)
        #expect(viewModel.isAuthorNameValid)
        #expect(viewModel.isAuthorEmailValid == false)
        #expect(viewModel.canSubmitRatingOrComment == false)
    }

    /// Name longer than 40 chars fails the shared validator → disabled.
    @Test func canSubmitIsFalseWithOverlongName() async throws {
        let viewModel = Self.makeReadyViewModel(id: 806)
        viewModel.setCommentAuthorName(String(repeating: "a", count: 41))
        viewModel.setCommentAuthorEmail("a@b.com")
        viewModel.setCommentDraft("Nice.")
        #expect(viewModel.isAuthorNameValid == false)
        #expect(viewModel.canSubmitRatingOrComment == false)
    }

    // MARK: - Single submit routing

    /// Stars only (no comment) → the consolidated submit routes to the
    /// rating POST and updates the summary. Crucially it must NOT fire a
    /// comment POST (no `.recipeCommentSubmitted`).
    @Test func submitWithRatingOnlyRoutesToRatingPost() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 810, withDetail: true)
        dependencies.guestIdentity = (name: "Jamie", email: "jamie@example.com")
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 810)
        await viewModel.onAppear()

        viewModel.setPendingRating(5)
        await viewModel.submitRatingAndComment()

        #expect(viewModel.ratingSummary?.userRating == 5)
        let rated = dependencies.telemetryEvents.contains { event in
            if case .recipeRated = event { return true }
            return false
        }
        let commented = dependencies.telemetryEvents.contains { event in
            if case .recipeCommentSubmitted = event { return true }
            return false
        }
        #expect(rated, "Stars-only submit must POST the rating")
        #expect(commented == false, "Stars-only submit must NOT POST a comment")
    }

    /// DUT-31: a comment **with** stars must record the rating via the proven
    /// WPRM path (`.recipeRated` → `postRating`) AND post the comment
    /// (`.recipeCommentSubmitted`). The comment meta alone does NOT land the
    /// rating (WordPress drops `meta.wprm_comment_rating` on REST comment
    /// create), so the old "comment carries the rating" behavior silently lost
    /// it. The comment still owns the snackbar.
    @Test func submitWithCommentAndRatingRecordsRatingViaWPRMAndPostsComment() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 811, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
        dependencies.postedRatingResult = RecipeRating(
            recipeID: 811,
            average: 4.8,
            count: 25,
            userRating: 5
        )
        dependencies.postedCommentResult = RecipeDetailTestFixtures.makeComment(
            id: 5001,
            postID: 811,
            body: "Loved it.",
            status: .approved
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 811)
        await viewModel.onAppear()

        viewModel.setPendingRating(5)
        viewModel.setCommentDraft("Loved it.")
        await viewModel.submitRatingAndComment()

        // The comment owns the final snackbar (rating is recorded quietly).
        #expect(viewModel.snackbarMessage == "Comment posted.")
        #expect(viewModel.comments.first?.id == 5001)
        // The rating aggregate refreshed from the WPRM round-trip.
        #expect(viewModel.ratingSummary?.userRating == 5)
        #expect(viewModel.ratingSummary?.average == 4.8)
        let commented = dependencies.telemetryEvents.contains { event in
            if case .recipeCommentSubmitted = event { return true }
            return false
        }
        let rated = dependencies.telemetryEvents.contains { event in
            if case .recipeRated(_, let stars) = event { return stars == 5 }
            return false
        }
        #expect(commented, "Comment submit must POST the comment")
        #expect(rated, "DUT-31: comment + rating must ALSO record the rating via WPRM")
        // DUT-28: the consolidated submit persists the (pre-filled) identity.
        #expect(dependencies.savedGuestIdentities.count == 1)
        #expect(dependencies.savedGuestIdentities.first?.email == "sam@example.com")
    }

    /// DUT-31 guard rail: a comment with NO stars must NOT fire the WPRM
    /// rating POST — only the genuine comment+rating combo records a rating.
    @Test func submitWithCommentButNoRatingDoesNotRecordRating() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 815, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
        dependencies.postedCommentResult = RecipeDetailTestFixtures.makeComment(
            id: 5002,
            postID: 815,
            body: "No stars from me.",
            status: .approved
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 815)
        await viewModel.onAppear()

        viewModel.setCommentDraft("No stars from me.")
        await viewModel.submitRatingAndComment()

        #expect(viewModel.snackbarMessage == "Comment posted.")
        let rated = dependencies.telemetryEvents.contains { event in
            if case .recipeRated = event { return true }
            return false
        }
        #expect(rated == false, "A comment with no stars must not record a rating")
    }

    /// DUT-31 / DUT-738: even if recording the rating fails, the comment still
    /// posts and is never blocked by a rating hiccup. DUT-738 supersedes the
    /// original "stay silent" choice: the star vote is genuinely lost when the
    /// WPRM rating POST fails (the comment meta doesn't carry it), so the
    /// snackbar now tells the user their rating didn't save — comment-success
    /// first — mirroring the DUT-395 inverse (rating-saved-but-comment-failed).
    @Test func submitCommentAndRatingStillPostsCommentWhenRatingRecordingFails() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 816, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
        dependencies.postRatingShouldFail = true
        dependencies.postedCommentResult = RecipeDetailTestFixtures.makeComment(
            id: 5003,
            postID: 816,
            body: "Rating endpoint is down but the comment still lands.",
            status: .approved
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 816)
        await viewModel.onAppear()

        viewModel.setPendingRating(4)
        viewModel.setCommentDraft("Rating endpoint is down but the comment still lands.")
        await viewModel.submitRatingAndComment()

        // DUT-738: comment posted, but the rating POST failed — the vote is lost,
        // so the user is told (instead of a bare "Comment posted." that hides it).
        #expect(
            viewModel.snackbarMessage
                == "Your comment posted, but your rating didn't save. Try the stars again."
        )
        #expect(viewModel.comments.first?.id == 5003)
        let commented = dependencies.telemetryEvents.contains { event in
            if case .recipeCommentSubmitted = event { return true }
            return false
        }
        #expect(commented, "Comment must post even when the rating record fails")
    }

    /// Nothing entered → the consolidated submit is a no-op (no POST of
    /// either kind). The button is disabled in the UI, but the method must
    /// be defensive too.
    @Test func submitWithNothingIsANoOp() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 812, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 812)
        await viewModel.onAppear()

        await viewModel.submitRatingAndComment()

        let posted = dependencies.telemetryEvents.contains { event in
            switch event {
            case .recipeRated, .recipeCommentSubmitted: return true
            default: return false
            }
        }
        #expect(posted == false, "Empty submit must not POST anything")
    }

    // MARK: - Submit blocked on invalid identity (DUT-28)

    /// Content present but the on-form identity is invalid → the consolidated
    /// submit must block with a snackbar and fire NO POST (and persist
    /// nothing). Replaces the old "re-gate behind the pop-up" behavior.
    @Test func submitWithInvalidIdentityBlocksAndDoesNotPostOrPersist() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 813, withDetail: true)
        // No saved identity; the user enters a malformed email on the form.
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 813)
        await viewModel.onAppear()

        viewModel.setCommentAuthorName("Jamie")
        viewModel.setCommentAuthorEmail("nope")
        viewModel.setCommentDraft("Tried it.")
        await viewModel.submitRatingAndComment()

        #expect(viewModel.snackbarMessage == "Add your name and a valid email to submit.")
        // The draft survives so the user can fix the email and retry.
        #expect(viewModel.commentDraft == "Tried it.")
        let posted = dependencies.telemetryEvents.contains { event in
            switch event {
            case .recipeRated, .recipeCommentSubmitted: return true
            default: return false
            }
        }
        #expect(posted == false, "Invalid identity must not POST anything")
        #expect(dependencies.savedGuestIdentities.isEmpty, "Invalid identity must not be persisted")
    }

    /// Stars-only submit with a valid on-form identity also persists it (the
    /// rating path is not exempt from the DUT-28 persistence contract).
    @Test func submitRatingOnlyPersistsOnFormIdentity() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 814, withDetail: true)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 814)
        await viewModel.onAppear()

        viewModel.setCommentAuthorName("Robin")
        viewModel.setCommentAuthorEmail("robin@example.com")
        viewModel.setPendingRating(4)
        await viewModel.submitRatingAndComment()

        #expect(viewModel.ratingSummary?.userRating == 4)
        #expect(dependencies.savedGuestIdentities.first?.name == "Robin")
    }

    // MARK: - Helpers

    @MainActor
    static func makeReadyViewModel(
        id: Int,
        withValidIdentity: Bool = false
    ) -> RecipeDetailViewModel {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: id, withDetail: true)
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: id)
        if withValidIdentity {
            // DUT-28: seed the on-form identity directly so the gating tests
            // can isolate the "has content" half of `canSubmitRatingOrComment`.
            viewModel.setCommentAuthorName("Jamie")
            viewModel.setCommentAuthorEmail("jamie@example.com")
        }
        return viewModel
    }

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

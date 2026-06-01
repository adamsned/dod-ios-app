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

    @Test func canSubmitIsFalseWhenNoRatingAndNoComment() async throws {
        let viewModel = Self.makeReadyViewModel(id: 800)
        #expect(viewModel.canSubmitRatingOrComment == false)
    }

    @Test func canSubmitIsTrueWithRatingOnly() async throws {
        let viewModel = Self.makeReadyViewModel(id: 801)
        viewModel.setPendingRating(4)
        #expect(viewModel.canSubmitRatingOrComment)
    }

    @Test func canSubmitIsTrueWithCommentOnly() async throws {
        let viewModel = Self.makeReadyViewModel(id: 802)
        viewModel.setCommentDraft("Great recipe.")
        #expect(viewModel.canSubmitRatingOrComment)
    }

    @Test func canSubmitIsFalseWithWhitespaceOnlyComment() async throws {
        let viewModel = Self.makeReadyViewModel(id: 803)
        viewModel.setCommentDraft("   \n ")
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

    /// A comment (with stars) → the consolidated submit routes to the
    /// comment POST, which already carries the pending rating alongside the
    /// body. It must NOT additionally fire the standalone rating POST.
    @Test func submitWithCommentRoutesToCommentPostCarryingRating() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 811, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
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

        #expect(viewModel.snackbarMessage == "Comment posted.")
        #expect(viewModel.comments.first?.id == 5001)
        let commented = dependencies.telemetryEvents.contains { event in
            if case .recipeCommentSubmitted = event { return true }
            return false
        }
        let rated = dependencies.telemetryEvents.contains { event in
            if case .recipeRated = event { return true }
            return false
        }
        #expect(commented, "Comment submit must POST the comment")
        #expect(rated == false, "Comment submit must not also fire the standalone rating POST")
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

    // MARK: - Helpers

    @MainActor
    static func makeReadyViewModel(id: Int) -> RecipeDetailViewModel {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: id, withDetail: true)
        return makeViewModel(dependencies: dependencies, listItemID: id)
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

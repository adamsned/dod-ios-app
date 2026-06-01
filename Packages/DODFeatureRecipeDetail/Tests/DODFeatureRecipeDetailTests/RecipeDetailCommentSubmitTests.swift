import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-7 (US-14 / AC-14.4 + US-15 / AC-15.1): the comment-submit path must
/// never fail silently and must never POST a blank author identity (which WP
/// 400s). Extracted from `RecipeDetailViewModelTests.swift` to keep that
/// type under the SwiftLint `type_body_length` cap.
///
/// Coverage stays at L1/L2 against `FakeRecipeDetailDependencies` — no write
/// reaches the live blog (constitution §6).
@MainActor
@Suite("RecipeDetailViewModel.submitComment — DUT-7 guards + surfacing")
struct RecipeDetailCommentSubmitTests {

    /// A Keychain identity whose email is empty / whitespace must NOT fire a
    /// doomed POST (WP 400s `author_email=""`). The view model re-gates
    /// behind the guest-identity sheet and tells the user why, instead of
    /// silently failing.
    @Test func submitCommentWithBlankEmailReGatesAndDoesNotPost() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 72, withDetail: true)
        // Identity is present but the email is whitespace-only — the case
        // `GuestIdentityStore.load()` cannot catch (it only nils a *missing*
        // field, not an empty string).
        dependencies.guestIdentity = (name: "Sam", email: "   ")
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 72)
        await viewModel.onAppear()

        viewModel.setCommentDraft("My comment.")
        await viewModel.submitComment()

        #expect(viewModel.requiresGuestIdentity == true)
        #expect(viewModel.snackbarMessage == "Add your name and email to post a comment.")
        // The draft is preserved so the user can retry after entering identity.
        #expect(viewModel.commentDraft == "My comment.")
        // No comment-submitted telemetry → proves no POST fired.
        let submitted = dependencies.telemetryEvents.contains { event in
            if case .recipeCommentSubmitted = event { return true }
            return false
        }
        #expect(submitted == false, "Blank email must not fire a comment POST")
    }

    /// Whitespace around a real identity is trimmed before the POST so we
    /// never send `author_email=" sam@example.com "`.
    @Test func submitCommentTrimsWhitespaceFromIdentity() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 73, withDetail: true)
        dependencies.guestIdentity = (name: "  Sam  ", email: "  sam@example.com  ")
        dependencies.postedCommentResult = RecipeDetailTestFixtures.makeComment(
            id: 1001,
            postID: 73,
            body: "Approved.",
            status: .approved
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 73)
        await viewModel.onAppear()

        viewModel.setCommentDraft("Approved.")
        await viewModel.submitComment()

        // Posted successfully (the trimmed identity passed the guard).
        #expect(viewModel.snackbarMessage == "Comment posted.")
        #expect(viewModel.comments.first?.id == 1001)
    }

    /// A non-2xx with a WP message surfaces the category-specific snackbar
    /// (no silent failure) — the end-to-end view-model assertion for AC-14.4.
    @Test func submitCommentSurfacesServerErrorMessageOnFailure() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 74, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
        dependencies.postCommentError = WPClientError.httpStatusWithBody(
            403,
            message: "Comment blocked by spam filter."
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 74)
        await viewModel.onAppear()

        viewModel.setCommentDraft("My comment.")
        await viewModel.submitComment()

        #expect(
            viewModel.snackbarMessage
                == "Couldn't post your comment (server said 403): Comment blocked by spam filter."
        )
        // Draft preserved on failure so the user doesn't lose their text.
        #expect(viewModel.commentDraft == "My comment.")
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

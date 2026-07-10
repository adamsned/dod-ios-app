import DODDomain
import DODFeatureProfile
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

    /// DUT-28: an on-form email that is empty / whitespace must NOT fire a
    /// doomed POST (WP 400s `author_email=""`). The view model blocks and
    /// tells the user why, instead of silently failing. (A whitespace email
    /// pre-filled from a partially-saved Keychain row reaches the form via
    /// `prefillAuthorIdentity()`, so the guard still has to catch it here.)
    @Test func submitCommentWithBlankEmailBlocksAndDoesNotPost() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 72, withDetail: true)
        // Pre-fill seeds a whitespace-only email onto the form — the case a
        // simple `isEmpty` check on the saved row cannot catch.
        dependencies.guestIdentity = (name: "Sam", email: "   ")
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 72)
        await viewModel.onAppear()

        viewModel.setCommentDraft("My comment.")
        await viewModel.submitComment()

        #expect(viewModel.snackbarMessage == "Add your name and email to post a comment.")
        // The draft is preserved so the user can retry after fixing the email.
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

    /// DUT-27: a successful post that WordPress holds for moderation (status
    /// `.hold`) must (a) show the prominent positive confirmation so the user
    /// knows it SUCCEEDED and does not re-submit, (b) clear the draft, and
    /// (c) optimistically insert the pending comment locally so the user sees
    /// their words — `CommentRow` renders the non-approved status with the
    /// "Awaiting approval" badge.
    @Test func submitCommentPendingShowsConfirmationAndInsertsLocally() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 80, withDetail: true)
        dependencies.guestIdentity = (name: "Ned", email: "ned@example.com")
        dependencies.postedCommentResult = RecipeDetailTestFixtures.makeComment(
            id: 5001,
            postID: 80,
            body: "I love this recipe!",
            status: .hold
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 80)
        await viewModel.onAppear()

        viewModel.setCommentDraft("I love this recipe!")
        await viewModel.submitComment()

        #expect(viewModel.snackbarMessage == "Comment submitted. It will appear after approval.")
        // Draft cleared so the field reads "submitted", reducing re-submits.
        #expect(viewModel.commentDraft.isEmpty)
        // Optimistically inserted, and still flagged pending so the row shows
        // the "Awaiting approval" badge.
        #expect(viewModel.comments.first?.id == 5001)
        #expect(viewModel.comments.first?.status == .hold)
        // DUT-387: the held comment is cached into the PENDING bucket (not as a
        // normal public row), so a relaunch keeps showing it with the "Awaiting
        // approval" badge and it's dropped/flipped rather than stuck forever.
        let pendingWrite = dependencies.cachedPendingCommentWrites.last
        #expect(pendingWrite?.comment.id == 5001)
        #expect(pendingWrite?.postID == 80)
        // And the held comment is NOT written to the normal (approved) cache —
        // that's the DUT-387 defect (it made a rejected comment stick forever).
        #expect(
            dependencies.cachedCommentWrites.allSatisfy { write in
                !write.comments.contains { $0.id == 5001 }
            }
        )
    }

    /// DUT-433: a successful ONLINE comments refresh must not wipe this
    /// device's still-pending comment from the thread — the public GET never
    /// returns `hold` rows, so `comments = approved` alone made the author's
    /// awaiting-approval comment vanish on every re-open (the "did my comment
    /// post?" re-submit loop). The cached pending row is re-appended.
    @Test func onlineRefreshKeepsPendingCommentVisible() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 90, withDetail: true)
        let approved = RecipeDetailTestFixtures.makeComment(
            id: 7001,
            postID: 90,
            body: "Public.",
            status: .approved
        )
        let pending = RecipeDetailTestFixtures.makeComment(
            id: 7002,
            postID: 90,
            body: "Mine, awaiting approval.",
            status: .hold
        )
        // Cache hydration returns approved + this device's pending row; the
        // network page returns ONLY the approved comment.
        dependencies.cachedCommentsByPost[90] = [approved, pending]
        dependencies.fetchedComments = [approved]
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 90)
        await viewModel.onAppear()

        #expect(viewModel.comments.contains { $0.id == 7001 })
        #expect(
            viewModel.comments.contains { $0.id == 7002 && $0.status == .hold },
            "The author's pending comment must survive the online refresh"
        )
    }

    /// DUT-433: once WP approves the comment, the fresh page supersedes the
    /// cached pending row — no duplicate.
    @Test func onlineRefreshDeduplicatesOnceApproved() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 91, withDetail: true)
        let nowApproved = RecipeDetailTestFixtures.makeComment(
            id: 7003,
            postID: 91,
            body: "Mine.",
            status: .approved
        )
        let stalePending = RecipeDetailTestFixtures.makeComment(
            id: 7003,
            postID: 91,
            body: "Mine.",
            status: .hold
        )
        dependencies.cachedCommentsByPost[91] = [stalePending]
        dependencies.fetchedComments = [nowApproved]
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 91)
        await viewModel.onAppear()

        #expect(viewModel.comments.filter { $0.id == 7003 }.count == 1)
        #expect(viewModel.comments.first { $0.id == 7003 }?.status == .approved)
    }

    /// DUT-27 (build 8): a 409 that carries the WordPress "Duplicate comment
    /// detected …" body surfaces the FRIENDLY duplicate line end-to-end — not
    /// the raw "server said 409: …" text — and the draft is preserved.
    @Test func submitCommentDuplicate409ShowsFriendlyMessage() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 81, withDetail: true)
        dependencies.guestIdentity = (name: "Ned", email: "ned@example.com")
        dependencies.postCommentError = WPClientError.httpStatusWithBody(
            409,
            message: "Duplicate comment detected; it looks as though you\u{2019}ve already said that!"
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 81)
        await viewModel.onAppear()

        viewModel.setCommentDraft("I love this recipe!")
        await viewModel.submitComment()

        #expect(
            viewModel.snackbarMessage == "Looks like you already posted this. It may be awaiting approval."
        )
        #expect(viewModel.snackbarMessage?.contains("409") == false)
        // Draft preserved (the user might be trying to edit + repost).
        #expect(viewModel.commentDraft == "I love this recipe!")
    }

    /// DUT-27: a bare `.httpStatus(409)` (no body) on this path is also a
    /// duplicate verdict and gets the same friendly treatment.
    @Test func submitCommentBare409ShowsFriendlyMessage() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 82, withDetail: true)
        dependencies.guestIdentity = (name: "Ned", email: "ned@example.com")
        dependencies.postCommentError = WPClientError.httpStatus(409)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 82)
        await viewModel.onAppear()

        viewModel.setCommentDraft("I love this recipe!")
        await viewModel.submitComment()

        #expect(
            viewModel.snackbarMessage == "Looks like you already posted this. It may be awaiting approval."
        )
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

    // MARK: - Phase d (T-742 / CL-139) — composer auto-fill + own-comment stamp

    /// AC-44.12: the WP REST `author_name` + `author_email` payload values
    /// are sourced from the profile, not from a retired on-form field.
    /// Pins that the comment-submit path routes `profile.displayName` +
    /// `profile.email` through to ``postComment(...)``.
    @Test func submitRoutesProfileNameAndEmailToPostComment() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 90, withDetail: true)
        dependencies.profileToLoad = UserProfile(
            id: UUID(),
            displayName: "Spencer Adams",
            email: "spencer@example.com",
            photoFilename: nil
        )
        dependencies.postedCommentResult = RecipeDetailTestFixtures.makeComment(
            id: 9001,
            postID: 90,
            body: "Loved it.",
            status: .approved
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 90)
        await viewModel.onAppear()

        viewModel.setCommentDraft("Loved it.")
        await viewModel.submitComment()

        let captured = dependencies.lastPostCommentNameEmail
        #expect(captured?.name == "Spencer Adams")
        #expect(captured?.email == "spencer@example.com")
    }

    /// AC-44.13: the just-posted comment is stamped with the profile email
    /// before insertion so own-comment row rendering can match against
    /// `profile.email` and swap in `ProfilePhotoView`. WordPress's GET
    /// doesn't return `author_email`, so the local stamp is the only way
    /// the row picks up the profile photo in-session.
    @Test func submitStampsAuthorEmailOnReturnedCommentForOwnAvatarRendering() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 91, withDetail: true)
        dependencies.profileToLoad = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: nil
        )
        // postComment fake returns a result with `authorEmail = ""` (the
        // wire-format default, since WP GET payloads strip the email).
        dependencies.postedCommentResult = RecipeDetailTestFixtures.makeComment(
            id: 9101,
            postID: 91,
            body: "First!",
            status: .approved
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 91)
        await viewModel.onAppear()

        viewModel.setCommentDraft("First!")
        await viewModel.submitComment()

        // The just-inserted comment carries the profile email so own-row
        // matching can fire.
        let inserted = viewModel.comments.first
        #expect(inserted?.id == 9101)
        #expect(inserted?.authorEmail == "spencer@example.com")
    }

    /// AC-44.13: the equality check is case-insensitive — emails are
    /// canonically case-insensitive per RFC 5321 and a user typing
    /// `Spencer@Example.com` into the profile must still match the
    /// `spencer@example.com` echo from the wire / submit path. The
    /// helper is a pure function over two strings so a focused test
    /// pins the contract without a view host.
    @Test func stampedEmailMatchesProfileEmailCaseInsensitively() throws {
        let stamped = RecipeDetailViewModel.stampAuthorEmail(
            RecipeDetailTestFixtures.makeComment(
                id: 9201,
                postID: 92,
                body: "Hi",
                status: .approved
            ),
            email: "Spencer@Example.com"
        )
        let profileEmail = "spencer@example.com"
        #expect(stamped.authorEmail.lowercased() == profileEmail.lowercased())
    }

    /// AC-44.7 / AC-44.13: old guest-attributed comments with empty
    /// `authorEmail` naturally fall through (the existing avatar path)
    /// because empty doesn't equal a real profile's email. No special
    /// case is needed — the equality check handles it by construction.
    @Test func guestCommentsWithEmptyEmailDoNotMatchProfile() throws {
        let guestComment = RecipeDetailTestFixtures.makeComment(
            id: 9301,
            postID: 93,
            body: "Hi",
            status: .approved
        )
        let profileEmail = "spencer@example.com"
        // The fixture leaves `authorEmail` as the empty-string default.
        #expect(guestComment.authorEmail.isEmpty)
        #expect(guestComment.authorEmail.lowercased() != profileEmail.lowercased())
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

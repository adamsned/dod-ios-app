import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-576 — the Ratings & Reviews header must not render blank when a recipe
/// has 0 ratings and its only comment is moderation-hidden (reported/blocked).
///
/// The bug (`RecipeDetailRatingsSection.ratingsHeader`) gated the "Be the first
/// to rate this recipe." invitation on the UNFILTERED `viewModel.comments`
/// while `commentsList` renders `viewModel.visibleComments` (comments minus
/// reported/blocked). When a recipe had 0 ratings + exactly one comment that
/// the user reported, `visibleComments` was empty (list showed "No comments
/// yet…") but `comments` was NOT — so the header fell through to NEITHER the
/// aggregate NOR the invitation, leaving a blank header over an empty list.
/// The fix gates the header on `visibleComments.isEmpty`.
///
/// Spec trace: DUT-576, DUT-546 moderation surface, AC-44.14 / CL-140.
@MainActor
@Suite("RecipeDetailRatingsSection header — moderation (DUT-576)")
struct RecipeDetailRatingsHeaderModerationTests {

    /// A recipe with 0 ratings AND exactly one comment that the user then reports
    /// (moderation-hides) must show the invitation, NOT a blank header. We pin
    /// the gate input: after the report, `visibleComments` is empty (invitation
    /// shows) even though `comments` is not — the state that blanked the header
    /// under the buggy `comments.isEmpty` gate.
    @Test func ratingsHeaderShowsInvitationWhenOnlyCommentIsModerationHidden() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 576, withDetail: true)
        // 0 ratings + exactly one comment (the DUT-546 moderation shape).
        let onlyComment = RecipeDetailTestFixtures.makeComment(
            id: 5760,
            postID: 576,
            body: "The one comment the user will hide."
        )
        dependencies.fetchedComments = [onlyComment]
        // Isolated moderation store so the report doesn't leak into `.standard`.
        let suiteName = "dod.tests.moderation.dut576.\(UUID().uuidString)"
        let moderationDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { moderationDefaults.removePersistentDomain(forName: suiteName) }
        let viewModel = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 576),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/576/") ?? URL(filePath: "/"),
            dependencies: dependencies,
            commentModeration: CommentModerationStore(defaults: moderationDefaults)
        )

        await viewModel.onAppear()

        // Precondition: the one comment loaded, no ratings.
        #expect(viewModel.comments.count == 1)
        #expect((viewModel.ratingSummary?.count ?? 0) == 0)

        // User reports (hides) the only comment.
        viewModel.reportComment(onlyComment)

        // The list is now empty (renders "No comments yet…"), but the raw
        // `comments` array is NOT — the exact state that blanked the header.
        #expect(viewModel.visibleComments.isEmpty)
        #expect(viewModel.comments.isEmpty == false)

        // Header gate (the fix): invitation renders iff no ratings AND the
        // VISIBLE comments are empty. On the buggy `comments.isEmpty` gate this
        // was `false` (blank header); on `visibleComments.isEmpty` it is `true`.
        let summaryCount = viewModel.ratingSummary?.count ?? 0
        let shouldRenderInvitation = summaryCount == 0 && viewModel.visibleComments.isEmpty
        #expect(shouldRenderInvitation, "0 ratings + only comment hidden → invitation must render")
    }
}

import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-742 — regression coverage for the two comment/rating DATA-LOSS bugs:
///
///  * BUG 2 (critical): the device's own moderation-held comment must survive
///    an approved-only refetch (and app relaunch) instead of being clobbered,
///    then dedupe by CONTENT — not the fragile server id — once it returns
///    approved.
///  * BUG 1: the star the user attached must persist with the comment through
///    that cycle, and must not be lost when the separate WPRM aggregate POST
///    fails.
///
/// Coverage stays at L1/L2 against `FakeRecipeDetailDependencies` — no write
/// reaches the live blog (constitution §6).
@MainActor
@Suite("RecipeDetailViewModel — comment + rating persistence (DUT-742)")
struct RecipeDetailCommentPersistenceTests {

    // MARK: - Pure reconcile helper (BUG 2 core)

    /// (a) A still-pending own-comment the approved page does NOT contain is
    /// kept — never dropped by the approved-only fetch.
    @Test func pendingCommentSurvivesApprovedPageWithoutIt() {
        let pending = Self.makeComment(
            id: 555,
            body: "Best chili ever.",
            rating: 5,
            status: .hold
        )
        let approved = [Self.makeComment(id: 1, body: "Someone else.", status: .approved)]

        let result = RecipeDetailViewModel.reconcileComments(
            approved: approved,
            cached: [approved[0], pending]
        )

        #expect(result.visible.contains { $0.body == "Best chili ever." })
        #expect(result.visible.count == 2)
        // The pending row is NOT written back as a public/approved row.
        #expect(result.toCache.contains { $0.body == "Best chili ever." } == false)
    }

    /// (b) Once the same comment returns approved — even under a DIFFERENT
    /// server id than the moderation-time echo — it dedupes to one row.
    /// (c) …and the rating is carried forward onto the approved copy, which
    /// WordPress returns rating-less.
    @Test func approvedCopyDedupesByContentAndKeepsRating() throws {
        // Pending copy: no usable server id (0), carries the user's star.
        let pending = Self.makeComment(
            id: 0,
            body: "Loved it!",
            rating: 4,
            status: .hold
        )
        // Server copy of the SAME comment, now approved, different id, no star.
        let approvedSame = Self.makeComment(
            id: 98765,
            body: "Loved it!",
            rating: nil,
            status: .approved
        )

        let result = RecipeDetailViewModel.reconcileComments(
            approved: [approvedSame],
            cached: [pending]
        )

        // Exactly one row — no duplicate, no vanish.
        #expect(result.visible.count == 1)
        let row = try #require(result.visible.first)
        #expect(row.id == 98765)
        #expect(row.status == .approved)
        // The star survived the flip to approved.
        #expect(row.ratingValue == 4)
        // And the cached public row keeps it too.
        #expect(result.toCache.first?.ratingValue == 4)
    }

    /// `isSameComment` matches on a real shared id OR on content, and never
    /// collapses two distinct rows that only share the `0` no-id sentinel.
    @Test func isSameCommentMatchesContentButNotZeroID() {
        let helloHold = Self.makeComment(id: 0, body: "Hello", status: .hold)
        let byeApproved = Self.makeComment(id: 0, body: "Goodbye", status: .approved)
        #expect(RecipeDetailViewModel.isSameComment(helloHold, byeApproved) == false)

        let helloApproved = Self.makeComment(id: 7, body: "  HELLO  ", status: .approved)
        // content match, case/space folded:
        #expect(RecipeDetailViewModel.isSameComment(helloHold, helloApproved))

        let differentBodySameID = Self.makeComment(id: 7, body: "totally different", status: .hold)
        // shared real id:
        #expect(RecipeDetailViewModel.isSameComment(helloApproved, differentBodySameID))
    }

    // MARK: - Integration: submit → revisit (BUG 2 end-to-end)

    /// (a) end-to-end: post a held comment with a rating, then a later
    /// approved-only fetch that does NOT include it must not wipe it.
    @Test func heldCommentAndRatingPersistAcrossRevisit() async throws {
        let deps = FakeRecipeDetailDependencies()
        deps.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 300, withDetail: true)
        deps.guestIdentity = (name: "Sam", email: "sam@example.com")
        deps.postedCommentResult = Self.makeComment(
            id: 4242,
            body: "Awaiting approval please.",
            rating: nil,
            status: .hold
        )
        let vm = Self.makeViewModel(deps: deps, id: 300)
        await vm.onAppear()

        vm.setPendingRating(5)
        vm.setCommentDraft("Awaiting approval please.")
        await vm.submitRatingAndComment()

        // The held comment was routed to the pending bucket, WITH the star
        // stamped on (WP returned it rating-less).
        let pendingWrite = try #require(deps.cachedPendingCommentWrites.last)
        #expect(pendingWrite.comment.ratingValue == 5)
        #expect(vm.comments.contains { $0.id == 4242 })

        // Simulate a later revisit: the cache replays the pending row, the
        // public GET returns approved-only (empty here — still held).
        deps.cachedCommentsByPost[300] = [pendingWrite.comment]
        deps.fetchedComments = []
        await vm.loadRatingsAndComments()

        // The comment (and its star) survive — not clobbered by approved-only.
        let survivor = try #require(vm.comments.first { $0.body == "Awaiting approval please." })
        #expect(survivor.ratingValue == 5)
        #expect(survivor.status == .hold)
    }

    /// (b)+(c) end-to-end: after the comment is approved by WP (returned by
    /// the public GET under any id, rating-less), the thread shows exactly one
    /// row and it still carries the user's star.
    @Test func approvedRefetchDedupesAndKeepsRatingEndToEnd() async throws {
        let deps = FakeRecipeDetailDependencies()
        deps.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 301, withDetail: true)
        deps.guestIdentity = (name: "Sam", email: "sam@example.com")
        let vm = Self.makeViewModel(deps: deps, id: 301)
        await vm.onAppear()

        // Cache holds the still-pending own-comment (with its star).
        let pending = Self.makeComment(
            id: 500,
            body: "Ten out of ten.",
            rating: 3,
            status: .hold
        )
        deps.cachedCommentsByPost[301] = [pending]
        // WP now returns it approved under a NEW id, rating-less.
        deps.fetchedComments = [
            Self.makeComment(id: 900_001, body: "Ten out of ten.", rating: nil, status: .approved)
        ]
        await vm.loadRatingsAndComments()

        let rows = vm.comments.filter { $0.body == "Ten out of ten." }
        #expect(rows.count == 1, "approved copy must dedupe the pending copy")
        #expect(rows.first?.status == .approved)
        #expect(rows.first?.ratingValue == 3, "star carried forward onto the approved copy")
    }

    // MARK: - Integration: rating-post failure (BUG 1, requirement d)

    /// (d) when the WPRM aggregate rating POST fails during a combined
    /// comment+rating submit, the COMMENT still posts, the star is preserved
    /// locally (cached userRating + on the pending comment), and the user is
    /// told — nothing is silently lost.
    @Test func ratingPostFailureKeepsCommentAndPersistsRatingLocally() async throws {
        let deps = FakeRecipeDetailDependencies()
        deps.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 302, withDetail: true)
        deps.guestIdentity = (name: "Sam", email: "sam@example.com")
        deps.postRatingShouldFail = true  // the WPRM aggregate POST fails
        deps.postedCommentResult = Self.makeComment(
            id: 4343,
            body: "Great, rated it too.",
            rating: nil,
            status: .hold
        )
        let vm = Self.makeViewModel(deps: deps, id: 302)
        await vm.onAppear()

        vm.setPendingRating(4)
        vm.setCommentDraft("Great, rated it too.")
        await vm.submitRatingAndComment()

        // The comment survived (routed to the pending bucket) — not lost with
        // the rating.
        let pendingWrite = try #require(deps.cachedPendingCommentWrites.last)
        #expect(pendingWrite.comment.id == 4343)
        // The star is stamped on the comment AND persisted to the rating cache
        // locally (survives revisit + relaunch, re-seeds the stars control).
        #expect(pendingWrite.comment.ratingValue == 4)
        #expect(vm.pendingUserRating == 4)
        #expect(deps.cachedRatingByRecipe[302]?.userRating == 4)
        // The user is told the rating didn't save (copy owned by a sibling PR;
        // we only assert it's the rating half-state, not the exact wording).
        #expect(vm.snackbarMessage?.contains("rating") == true)
        // The comment draft was cleared → the comment itself posted fine.
        #expect(vm.commentDraft.isEmpty)
    }

    // MARK: - Helpers

    static func makeComment(
        id: Int,
        body: String,
        rating: Int? = nil,
        status: RecipeComment.Status
    ) -> RecipeComment {
        RecipeComment(
            id: id,
            postID: 1,
            parentID: nil,
            authorName: "Sam",
            authorEmail: "",
            avatarURL: nil,
            dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
            body: body,
            ratingValue: rating,
            status: status
        )
    }

    static func makeViewModel(deps: FakeRecipeDetailDependencies, id: Int) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: id),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
            dependencies: deps
        )
    }
}

import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// Regression coverage for the bug that hid the ratings + comments section
/// from the running app even though the underlying view model's unit
/// tests were green: the App-target build was failing at SwiftLint (an
/// `empty_count` violation on `ratingsHeader` plus oversized test file)
/// so the user kept running an older binary without the new section.
///
/// These tests don't rebuild the App — they pin the contract that the
/// view model presents the rendering surface unambiguously after the
/// recipe load, on every path:
///
/// * cached recipe (fast path) → `loadRatingsAndComments()` still runs
/// * fetched-and-parsed recipe (network path) → ditto
/// * empty payload → state is `.ready`, summary is zero (NOT `nil`),
///   comments are empty — the view must render an "empty" affordance
///   rather than disappear
/// * populated payload → summary + comments are surfaced verbatim
/// * blocked summary fetch → recipe still reaches `.ready`; comments
///   surface independently
///
/// Spec trace: US-13/14/15 rendering contract.
@MainActor
@Suite("RecipeDetailRatingsSection rendering") struct RecipeDetailRatingsRenderingTests {

    @Test func onAppearCallsLoadRatingsAndCommentsEvenWhenCacheHit() async throws {
        // Cache hit on the recipe — the fetch + parse branch is skipped.
        // Earlier wiring bugs that swallowed `loadRatingsAndComments()`
        // inside the cache-hit branch would have left the summary nil
        // and the spy counters at zero.
        //
        // T-736 / CL-133: the cache-hit branch now ALSO triggers a
        // background blurb-refresh fetch when online; force `online = false`
        // here so this test still asserts the original "HTML fetch is
        // skipped" intent without measuring the new refresh path (which
        // has its own dedicated `RecipeDetailViewModelBlurbRefreshTests`
        // coverage).
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = false
        dependencies.cachedRecipes[401] = RecipeDetailTestFixtures.makeRecipe(
            id: 401,
            withDetail: true
        )
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 401, average: 3.5, count: 4)
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 1, postID: 401, body: "Tasty.")
        ]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 401
        )

        await viewModel.onAppear()

        #expect(dependencies.fetchCount == 0, "Offline cache hit must skip the HTML fetch")
        #expect(
            dependencies.fetchRatingSummaryCallCount >= 1,
            "Ratings summary must load even on the cache-hit branch"
        )
        #expect(
            dependencies.cachedCommentsCallCount >= 1,
            "Cached comments must be queried even on the cache-hit branch"
        )
        #expect(viewModel.ratingSummary?.count == 4)
        #expect(viewModel.commentsLoadState == .ready)
    }

    @Test func onAppearCallsLoadRatingsAndCommentsEvenWhenFetchAndParse() async throws {
        // No cached recipe — the network path runs, *then*
        // `loadRatingsAndComments()` still has to run. A regression that
        // routed it inside an `else` arm would fail this case.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 402, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 402, average: 4.7, count: 21)
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 2, postID: 402, body: "Loved it.")
        ]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 402
        )

        await viewModel.onAppear()

        #expect(dependencies.fetchCount == 1, "Network path must run when there's no cache")
        #expect(
            dependencies.fetchRatingSummaryCallCount >= 1,
            "Ratings summary must load on the fetch-and-parse branch"
        )
        #expect(
            dependencies.cachedCommentsCallCount >= 1,
            "Cached comments must be queried on the fetch-and-parse branch"
        )
        #expect(viewModel.ratingSummary?.count == 21)
        #expect(viewModel.comments.count == 1)
    }

    @Test func ratingsSectionVisibleAfterReadyWithZeroData() async throws {
        // The view-layer regression: when WP returns an empty rating
        // summary AND no comments, the view must still render the
        // section (header + "Be the first..." + "No comments yet..."
        // placeholders). The view model has to expose enough
        // non-nil state to drive that — specifically a zero-valued
        // summary (REG-14) and a `.ready` comments state with an
        // empty array.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 403, withDetail: true)
        // `fetchedRatingSummary` left nil → fake returns the zero summary.
        // `fetchedComments` left empty → page is empty but the call succeeds.
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 403
        )

        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        // REG-14: a zero summary is still a *summary*, not nil. The
        // section's `ratingsHeader` branches on summary != nil to pick
        // between "Be the first…" and the aggregate display.
        let summary = try #require(viewModel.ratingSummary)
        #expect(summary.average == 0)
        #expect(summary.count == 0)  // swiftlint:disable:this empty_count
        #expect(summary.userRating == nil)
        #expect(viewModel.commentsLoadState == .ready)
        #expect(viewModel.comments.isEmpty)
    }

    @Test func ratingsSectionVisibleAfterReadyWithRealData() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 404, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 404, average: 4.5, count: 27)
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 11, postID: 404, body: "Made it twice."),
            RecipeDetailTestFixtures.makeComment(id: 12, postID: 404, body: "Family hit."),
        ]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 404
        )

        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        #expect(viewModel.ratingSummary?.average == 4.5)
        #expect(viewModel.ratingSummary?.count == 27)
        #expect(viewModel.comments.count == 2)
        #expect(viewModel.commentsLoadState == .ready)
    }

    @Test func ratingsSectionFiltersNonApprovedComments() async throws {
        // AC-14.2: only approved comments are rendered. A regression
        // that surfaced held/spam rows in the public list would still
        // satisfy the "count > 0" smoke check, so we pin the exact
        // filter behavior.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 405, withDetail: true)
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 1, postID: 405, body: "Approved.", status: .approved),
            RecipeDetailTestFixtures.makeComment(id: 2, postID: 405, body: "Held.", status: .hold),
            RecipeDetailTestFixtures.makeComment(id: 3, postID: 405, body: "Spam.", status: .spam),
        ]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 405
        )

        await viewModel.onAppear()

        #expect(viewModel.comments.count == 1)
        #expect(viewModel.comments.first?.id == 1)
    }

    @Test func loadRatingsAndCommentsDoesNotBlockRecipeReady() async throws {
        // Pin the contract: a slow / hung rating-summary fetch must NOT
        // prevent the recipe from reaching `.ready`. The recipe load runs
        // first; rating + comments hydration runs after. If a future
        // refactor reorders that, the rating gate would freeze the
        // whole detail screen.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 406, withDetail: true)

        // Sequence the gate around an awaited continuation so the test
        // can deterministically observe "recipe ready" while the rating
        // fetch is still pending.
        let resumeRatings = AsyncStream<Void>.makeStream()
        dependencies.fetchRatingSummaryGate = {
            for await _ in resumeRatings.stream { return }
        }

        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 406
        )

        // Run `onAppear` concurrently so we can peek at the view model
        // state while it's mid-flight. Without the parallel observer
        // we can't distinguish "blocked on rating fetch" from "fully
        // settled".
        let task = Task { await viewModel.onAppear() }

        // Spin until we see the recipe is ready OR a generous bound
        // elapses. The bound is intentionally short — the recipe load
        // is purely in-memory work via the fake.
        var attempts = 0
        while viewModel.loadState != .ready, attempts < 500 {
            try await Task.sleep(nanoseconds: 1_000_000)  // 1 ms
            attempts += 1
        }
        #expect(viewModel.loadState == .ready, "Recipe must be ready before rating fetch settles")

        // Now release the rating fetch and let `onAppear` finish.
        resumeRatings.continuation.yield(())
        resumeRatings.continuation.finish()
        await task.value
        #expect(viewModel.ratingSummary != nil)
    }

    @Test func cachedRatingSeedsPendingUserRatingForEditAffordance() async throws {
        // Pin the "Edit" UX: when the cache already holds this device's
        // userRating, the pending input should be seeded so the user can
        // tap "Submit rating" without re-picking the star count.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 407, withDetail: true)
        dependencies.cachedRatingByRecipe[407] = RecipeRating(
            recipeID: 407,
            average: 4.0,
            count: 1,
            userRating: 4
        )
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 407
        )

        await viewModel.onAppear()

        #expect(viewModel.pendingUserRating == 4)
    }

    @Test func onAppearPreFillsAuthorFieldsFromSavedIdentity() async throws {
        // DUT-28: the on-form name + email are pre-filled from the saved
        // guest identity on every onAppear, so a returning commenter sees
        // their details already populated (and editable) — no pop-up.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 408, withDetail: true)
        dependencies.guestIdentity = (name: "Pat", email: "pat@example.com")
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 408
        )

        await viewModel.onAppear()

        #expect(viewModel.commentAuthorName == "Pat")
        #expect(viewModel.commentAuthorEmail == "pat@example.com")
        // Both fields valid → the only thing left gating Submit is having
        // something to submit (a rating or comment).
        #expect(viewModel.isAuthorIdentityValid)
    }

    // MARK: - T-743 / CL-140 / AC-44.14 — empty-state label gate

    /// AC-44.14 (CL-140): the "Be the first to rate this recipe."
    /// invitation only renders when BOTH the ratings list AND the
    /// comments list are empty. These tests pin the underlying
    /// viewModel data combination that `ratingsHeader` consults.
    ///
    /// Truth table:
    /// - 0 ratings + 0 comments → label SHOWN (invitation).
    /// - ≥1 rating + 0 comments → aggregate SHOWN (label hidden).
    /// - 0 ratings + ≥1 comment → label HIDDEN (no aggregate either).
    /// - ≥1 rating + ≥1 comment → aggregate SHOWN (label hidden).
    ///
    /// We assert against `viewModel.ratingSummary?.count` and
    /// `viewModel.comments.isEmpty` because those ARE the gate inputs;
    /// the gate is a pure-function-of-state and pinning the state pins
    /// the gate output by construction.

    @Test func ratingsHeaderShowsInvitationWhenZeroRatingsAndZeroComments() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 501, withDetail: true)
        // No ratings, no comments — `ratingsHeader` should render the
        // "Be the first to rate this recipe." invitation.
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 501
        )

        await viewModel.onAppear()

        let summaryCount = viewModel.ratingSummary?.count ?? 0
        let commentsAreEmpty = viewModel.comments.isEmpty
        #expect(summaryCount == 0)  // swiftlint:disable:this empty_count
        #expect(commentsAreEmpty)
        // Gate condition: (summary.count == 0) && comments.isEmpty → label rendered.
        let shouldRenderInvitation = summaryCount == 0 && commentsAreEmpty
        #expect(shouldRenderInvitation, "0 ratings + 0 comments → invitation must render")
    }

    @Test func ratingsHeaderHidesInvitationWhenRatingsPresentAndZeroComments() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 502, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 502, average: 4.5, count: 3)
        // Ratings present, no comments — `ratingsHeader` renders the
        // StarRatingDisplay aggregate; the invitation is NOT shown.
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 502
        )

        await viewModel.onAppear()

        let summaryCount = viewModel.ratingSummary?.count ?? 0
        let commentsAreEmpty = viewModel.comments.isEmpty
        #expect(summaryCount > 0)
        #expect(commentsAreEmpty)
        // Gate: aggregate rendered (not the invitation).
        let shouldRenderAggregate = summaryCount > 0
        #expect(shouldRenderAggregate, ">0 ratings → aggregate must render")
    }

    @Test func ratingsHeaderHidesInvitationWhenZeroRatingsAndCommentsPresent() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 503, withDetail: true)
        // No ratings, at least one comment — `ratingsHeader` must NOT
        // render the invitation (conversation has started; only the
        // aggregate is missing). The header collapses to an EmptyView.
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 1, postID: 503, body: "Pre-rating tip.")
        ]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 503
        )

        await viewModel.onAppear()

        let summaryCount = viewModel.ratingSummary?.count ?? 0
        let commentsAreEmpty = viewModel.comments.isEmpty
        #expect(summaryCount == 0)  // swiftlint:disable:this empty_count
        #expect(commentsAreEmpty == false)
        // Gate: invitation hidden (no aggregate either — count is zero).
        let shouldRenderInvitation = summaryCount == 0 && commentsAreEmpty
        #expect(shouldRenderInvitation == false, "0 ratings + >0 comments → invitation must be hidden")
    }

    @Test func ratingsHeaderHidesInvitationWhenRatingsAndCommentsBothPresent() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 504, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 504, average: 4.7, count: 21)
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 11, postID: 504, body: "Loved it."),
        ]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 504
        )

        await viewModel.onAppear()

        let summaryCount = viewModel.ratingSummary?.count ?? 0
        let commentsAreEmpty = viewModel.comments.isEmpty
        #expect(summaryCount > 0)
        #expect(commentsAreEmpty == false)
        // Gate: aggregate rendered, invitation hidden.
        let shouldRenderAggregate = summaryCount > 0
        let shouldRenderInvitation = summaryCount == 0 && commentsAreEmpty
        #expect(shouldRenderAggregate, ">0 ratings + >0 comments → aggregate must render")
        #expect(shouldRenderInvitation == false, ">0 ratings + >0 comments → invitation must be hidden")
    }

    @Test func onAppearLeavesAuthorFieldsEmptyWhenNoSavedIdentity() async throws {
        // DUT-28: with nothing saved, the fields start empty (the user fills
        // them in) and the identity is not yet valid.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 409, withDetail: true)
        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 409
        )

        await viewModel.onAppear()

        #expect(viewModel.commentAuthorName.isEmpty)
        #expect(viewModel.commentAuthorEmail.isEmpty)
        #expect(viewModel.isAuthorIdentityValid == false)
    }
}

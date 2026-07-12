import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// Coverage for three genuinely-uncovered behaviors in the comment / rating
/// async flows of RecipeDetailViewModel that were absent from the prior suite:
///
///   * Standalone ``submitRating(stars:)`` failure — the specific snackbar
///     and the guarantee that the existing cached aggregate is not corrupted.
///   * ``prefillAuthorIdentity()`` — the "don't overwrite already-typed field"
///     branch (the DUT-28 "late background refresh must never clobber in-
///     progress edits" contract).
///   * ``persistAuthorIdentity()`` best-effort — a Keychain-write failure must
///     not block the comment POST; the identity save is side-effect, not gate.
///
/// Coverage stays at L1/L2 against FakeRecipeDetailDependencies — no write
/// reaches the live blog (constitution §6).
@MainActor
@Suite("RecipeDetailViewModel — comment / rating async flow gaps")
struct RecipeDetailCommentRatingGapTests {

    // MARK: - submitRating failure

    /// A standalone ``submitRating(stars:)`` POST failure must surface the
    /// "Couldn't save your rating. Try again." snackbar, leave the existing
    /// cached aggregate entirely unchanged (count, average), and fire no
    /// `.recipeRated` telemetry — nothing was actually recorded.
    @Test func submitRatingFailureSurfacesSnackbarAndPreservesAggregate() async {
        let deps = FakeRecipeDetailDependencies()
        deps.cachedRatingByRecipe[888] = RecipeRating(
            recipeID: 888,
            average: 4.2,
            count: 10,
            userRating: nil
        )
        deps.guestIdentity = (name: "Jamie", email: "jamie@example.com")
        deps.postRatingShouldFail = true
        let vm = Self.makeViewModel(deps: deps, id: 888)

        // Hydrate ratingSummary from the cache and prefill the author identity
        // so the guard in submitRating(stars:) does not block on empty fields.
        await vm.loadRatingsAndComments()
        #expect(vm.ratingSummary?.count == 10)

        await vm.submitRating(stars: 5)

        #expect(vm.snackbarMessage == "Couldn't save your rating. Try again.")
        // The cached aggregate must not be corrupted by the failure.
        #expect(vm.ratingSummary?.count == 10)
        #expect(vm.ratingSummary?.average == 4.2)
        // No rating was actually recorded — no telemetry event must fire.
        let ratedEventFired = deps.telemetryEvents.contains { event in
            if case .recipeRated = event { return true }
            return false
        }
        #expect(ratedEventFired == false, "A failed rating POST must not fire .recipeRated")
    }

    // MARK: - prefillAuthorIdentity: don't overwrite already-typed fields

    /// DUT-28: ``prefillAuthorIdentity()`` only seeds fields the user has NOT
    /// yet typed. If ``commentAuthorName`` is already non-empty when the saved
    /// identity loads, it must not be overwritten — a late background prefill
    /// must never clobber in-progress edits.
    ///
    /// The ``commentAuthorEmail`` field (empty in this test) IS seeded from
    /// the saved identity, confirming that the guard is field-granular.
    @Test func prefillDoesNotOverwriteAlreadyTypedName() async {
        let deps = FakeRecipeDetailDependencies()
        deps.guestIdentity = (name: "SavedName", email: "saved@example.com")
        let vm = Self.makeViewModel(deps: deps, id: 77)

        // Simulate the user having already typed a name on the form before
        // the background identity load finishes.
        vm.setCommentAuthorName("AlreadyTyped")
        #expect(vm.commentAuthorEmail.isEmpty)

        await vm.prefillAuthorIdentity()

        // The typed name must be preserved — not overwritten by "SavedName".
        #expect(vm.commentAuthorName == "AlreadyTyped")
        // The empty email IS seeded from the saved identity.
        #expect(vm.commentAuthorEmail == "saved@example.com")
    }

    // MARK: - persistAuthorIdentity: best-effort, never blocks the POST

    /// DUT-28: a Keychain-write failure in ``persistAuthorIdentity()`` must
    /// NOT block the comment POST. The identity save is best-effort — the
    /// values are valid in memory and the comment must still land. The
    /// comment's own success snackbar is the final, primary confirmation
    /// the user sees; the transient persist-failure message is overwritten.
    @Test func persistAuthorIdentityFailureDoesNotBlockCommentPost() async throws {
        let deps = FakeRecipeDetailDependencies()
        deps.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 999, withDetail: true)
        // guestIdentity pre-fills name + email on appear so the submit guard passes.
        deps.guestIdentity = (name: "Sam", email: "sam@example.com")
        // The Keychain write will throw, but the POST must still proceed.
        deps.saveGuestIdentityShouldFail = true
        deps.postedCommentResult = RecipeDetailTestFixtures.makeComment(
            id: 3001,
            postID: 999,
            body: "Good recipe.",
            status: .approved
        )
        let vm = Self.makeViewModel(deps: deps, id: 999)
        await vm.onAppear()

        vm.setCommentDraft("Good recipe.")
        await vm.submitRatingAndComment()

        // The identity save failed — nothing was written to the store.
        #expect(deps.savedGuestIdentities.isEmpty)
        // The comment still posted successfully.
        #expect(vm.snackbarMessage == "Comment posted.")
        // Draft cleared — confirms the POST went through.
        #expect(vm.commentDraft.isEmpty)
    }

    // MARK: - Helpers

    static func makeViewModel(
        deps: FakeRecipeDetailDependencies,
        id: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: id),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/")
                ?? URL(filePath: "/"),
            dependencies: deps
        )
    }
}

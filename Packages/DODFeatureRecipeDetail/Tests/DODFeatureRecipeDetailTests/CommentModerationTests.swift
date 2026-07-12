import DODDomain
import DODFeatureProfile
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-501 — App Store Review Guideline 1.2: users can report a comment and
/// block an author. These pin the filter + persistence + the report contact.
@MainActor
@Suite("Comment moderation — report/block (DUT-501)")
struct CommentModerationTests {

    private func isolatedDefaults() -> UserDefaults {
        let suite = "CommentModerationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func comment(id: Int, author: String) -> RecipeComment {
        RecipeComment(
            id: id,
            postID: 1,
            authorName: author,
            dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
            body: "body \(id)",
            status: .approved
        )
    }

    private func makeViewModel() -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 1),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/1/") ?? URL(filePath: "/"),
            dependencies: FakeRecipeDetailDependencies()
        )
    }

    // MARK: - Store

    @Test func blockingAnAuthorHidesTheirComments() {
        let store = CommentModerationStore(defaults: isolatedDefaults())
        let comment = comment(id: 1, author: "Spammy McSpam")
        #expect(store.isVisible(comment))
        store.block(author: "  spammy mcspam  ")  // trim + case-insensitive
        #expect(store.isVisible(comment) == false)
    }

    @Test func reportingHidesOnlyTheSpecificComment() {
        let store = CommentModerationStore(defaults: isolatedDefaults())
        store.hide(commentID: 5)
        #expect(store.isVisible(comment(id: 5, author: "Someone")) == false)
        #expect(store.isVisible(comment(id: 6, author: "Someone")))  // same author, not reported
    }

    @Test func blocksAndHidesSurviveAStoreReload() {
        let defaults = isolatedDefaults()
        let first = CommentModerationStore(defaults: defaults)
        first.block(author: "Troll")
        first.hide(commentID: 9)
        // A fresh store over the same defaults (i.e. a relaunch) still filters.
        let second = CommentModerationStore(defaults: defaults)
        #expect(second.isVisible(comment(id: 9, author: "X")) == false)
        #expect(second.isVisible(comment(id: 1, author: "Troll")) == false)
    }

    // DUT-546 gap 1 — a blank-name author can't be name-blocked (it would
    // collateral-block every other Anonymous author). `block(author:)` reports
    // the no-op via its return so the caller can fall back to hiding the row.
    @Test func blockingABlankNameAuthorReportsItCannotBlockByName() {
        let store = CommentModerationStore(defaults: isolatedDefaults())
        #expect(store.block(author: "   ") == false)
        #expect(store.blockedAuthors.isEmpty)
        #expect(store.block(author: "Real Name"))  // non-blank blocks + persists
        #expect(store.isVisible(comment(id: 1, author: "Real Name")) == false)
    }

    // DUT-565 — account teardown must wipe ALL moderation state so it can't leak
    // to the next device user. `clear()` empties both persisted keys AND the
    // in-memory `@Observable` sets (so an already-open screen re-shows the
    // previously-hidden comments), and a store constructed afterwards reads empty.
    @Test func clearEmptiesBothKeysAndInMemorySets() {
        let defaults = isolatedDefaults()
        let store = CommentModerationStore(defaults: defaults)
        store.block(author: "Troll")
        store.hide(commentID: 9)
        #expect(store.blockedAuthors.isEmpty == false)
        #expect(store.hiddenCommentIDs.isEmpty == false)

        store.clear()

        // In-memory sets reset immediately (an open screen reflects the reset).
        #expect(store.blockedAuthors.isEmpty)
        #expect(store.hiddenCommentIDs.isEmpty)
        #expect(store.isVisible(comment(id: 9, author: "Troll")))
        // Persisted keys removed: a fresh store over the same defaults reads empty.
        let reloaded = CommentModerationStore(defaults: defaults)
        #expect(reloaded.blockedAuthors.isEmpty)
        #expect(reloaded.hiddenCommentIDs.isEmpty)
    }

    @Test func isAnonymousDetectsBlankNames() {
        #expect(CommentModerationStore.isAnonymous(author: ""))
        #expect(CommentModerationStore.isAnonymous(author: "  \n "))
        #expect(CommentModerationStore.isAnonymous(author: "Ann") == false)
    }

    // MARK: - View model

    @Test func visibleCommentsFilterOutReportedAndBlocked() {
        let viewModel = makeViewModel()
        viewModel.commentModeration = CommentModerationStore(defaults: isolatedDefaults())
        viewModel.comments = [
            comment(id: 1, author: "Ann"),
            comment(id: 2, author: "Bob"),
            comment(id: 3, author: "Ann"),
        ]

        viewModel.reportComment(comment(id: 2, author: "Bob"))  // hide Bob's one comment
        #expect(viewModel.visibleComments.map(\.id) == [1, 3])

        viewModel.blockAuthor(of: comment(id: 1, author: "Ann"))  // both of Ann's go
        #expect(viewModel.visibleComments.isEmpty)
    }

    @Test func reportMailtoURLIsAValidModerationMailto() {
        let url = makeViewModel().reportMailtoURL(for: comment(id: 42, author: "Bad Actor"))
        let string = url?.absoluteString ?? ""
        #expect(string.hasPrefix("mailto:"))
        #expect(string.contains(RecipeDetailViewModel.moderationContactEmail))
        #expect(string.contains("42"))  // comment id carried into the report
    }

    // DUT-546 gap 1 — tapping "Block Anonymous" on a blank-name row must NOT be
    // a silent no-op. It falls back to hiding that specific comment (like
    // Report) and surfaces feedback, and the hidden state persists across a
    // store reload over the same defaults (relaunch-equivalent).
    @Test func blockingAnAnonymousCommentHidesItAndPersists() {
        let defaults = isolatedDefaults()
        let viewModel = makeViewModel()
        viewModel.commentModeration = CommentModerationStore(defaults: defaults)
        let anon = comment(id: 7, author: "   ")  // blank → "Anonymous"
        viewModel.comments = [anon, comment(id: 8, author: "Someone")]

        #expect(viewModel.snackbarMessage == nil)
        viewModel.blockAuthor(of: anon)  // the inert-before-DUT-546 path

        // Observable state changed — not a silent no-op.
        #expect(viewModel.snackbarMessage != nil)
        #expect(viewModel.visibleComments.map(\.id) == [8])
        // Persists: a fresh store over the same defaults still hides it.
        let reloaded = CommentModerationStore(defaults: defaults)
        #expect(reloaded.isVisible(anon) == false)
    }

    // DUT-546 gap 1 — a named author blocks by name (all their comments) and
    // surfaces confirmation feedback.
    @Test func blockingANamedAuthorConfirmsViaSnackbar() {
        let viewModel = makeViewModel()
        viewModel.commentModeration = CommentModerationStore(defaults: isolatedDefaults())
        viewModel.comments = [comment(id: 1, author: "Troll"), comment(id: 2, author: "Troll")]

        viewModel.blockAuthor(of: comment(id: 1, author: "Troll"))
        #expect(viewModel.snackbarMessage?.contains("Troll") == true)
        #expect(viewModel.visibleComments.isEmpty)  // both Troll rows gone
    }

    // DUT-546 gap 2 — a report whose mailto could not be opened (no mail
    // account) surfaces the published contact address as a fallback so the
    // report is still actionable; a successful open confirms instead. Neither
    // path is silent.
    @Test func reportAcknowledgementSurfacesFallbackWhenMailFails() {
        let viewModel = makeViewModel()
        let flagged = comment(id: 42, author: "Bad Actor")

        viewModel.acknowledgeReport(of: flagged, mailtoOpened: false)
        #expect(viewModel.snackbarMessage?.contains(RecipeDetailViewModel.moderationContactEmail) == true)
        #expect(viewModel.snackbarMessage?.contains("42") == true)

        viewModel.acknowledgeReport(of: flagged, mailtoOpened: true)
        #expect(viewModel.snackbarMessage?.contains("Reported") == true)
    }

    // DUT-546 gap 3 — two view models sharing ONE injected store: blocking on
    // screen A immediately hides the author on already-open screen B (the
    // @Observable set is authoritative process-wide, not per-view-model).
    @Test func sharedStorePropagatesBlockAcrossTwoViewModels() {
        let shared = CommentModerationStore(defaults: isolatedDefaults())
        let screenA = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 1),
            canonicalURL: URL(filePath: "/"),
            dependencies: FakeRecipeDetailDependencies(),
            commentModeration: shared
        )
        let screenB = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 2),
            canonicalURL: URL(filePath: "/"),
            dependencies: FakeRecipeDetailDependencies(),
            commentModeration: shared
        )
        screenB.comments = [comment(id: 1, author: "Troll")]
        #expect(screenB.visibleComments.count == 1)

        screenA.blockAuthor(of: comment(id: 9, author: "Troll"))  // block on A
        #expect(screenB.visibleComments.isEmpty)  // reflected on B, no reload
    }

    @Test func canModerateAnotherUsersComment() {
        // No profile signed in → nothing is "own" → every comment is moderatable.
        #expect(makeViewModel().canModerate(comment(id: 1, author: "Other")))
    }

    @Test func cannotBlockYourOwnNameEvenWhenTheServerRedactsYourEmail() {
        // Signed in as "Ned Adams". The server redacts author_email on read, so an
        // OWN older comment comes back with an empty email — email-based
        // `isOwnComment` misses it, but the name match must still count it as
        // yours. Otherwise (Block keys on the display name) blocking here would
        // hide every one of the user's own comments.
        let viewModel = makeViewModel()
        viewModel.profile = UserProfile(
            id: UUID(),
            displayName: "Ned Adams",
            email: "ned@dutchovendaddy.com"
        )
        let ownRedacted = comment(id: 1, author: "  ned adams  ")  // redacted email + odd casing/space

        // No Block/Report affordance on your own name.
        #expect(viewModel.canModerate(ownRedacted) == false)

        // And the direct backstop: blockAuthor refuses and doesn't self-block.
        viewModel.blockAuthor(of: ownRedacted)
        #expect(viewModel.snackbarMessage?.contains("your own name") == true)

        // Sanity: a different author is still fully moderatable.
        #expect(viewModel.canModerate(comment(id: 2, author: "Someone Else")))
    }
}

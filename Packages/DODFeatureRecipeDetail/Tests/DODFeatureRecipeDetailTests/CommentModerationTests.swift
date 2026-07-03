import DODDomain
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

    @Test func canModerateAnotherUsersComment() {
        // No profile signed in → nothing is "own" → every comment is moderatable.
        #expect(makeViewModel().canModerate(comment(id: 1, author: "Other")))
    }
}

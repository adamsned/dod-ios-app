import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

enum CommentDigestFixtures {
    static func comment(
        id: Int,
        body: String,
        age: TimeInterval = 0,
        status: RecipeComment.Status = .approved
    ) -> RecipeComment {
        RecipeComment(
            id: id,
            postID: 1,
            authorName: "Cook \(id)",
            dateGMT: Date(timeIntervalSince1970: 1_700_000_000 - age),
            body: body,
            status: status
        )
    }

    /// `count` approved comments, comment 0 newest.
    static func approved(_ count: Int) -> [RecipeComment] {
        (0..<count).map { comment(id: $0, body: "body \($0)", age: TimeInterval($0)) }
    }
}

@MainActor
struct CommentDigestStoreTests {
    @Test
    func approvedBodiesExcludesHeldSpamTrash() {
        let comments = [
            CommentDigestFixtures.comment(id: 1, body: "old approved", age: 100),
            CommentDigestFixtures.comment(id: 2, body: "held", age: 1, status: .hold),
            CommentDigestFixtures.comment(id: 3, body: "new approved", age: 10),
            CommentDigestFixtures.comment(id: 4, body: "spam", age: 0, status: .spam),
            CommentDigestFixtures.comment(id: 5, body: "trash", age: 0, status: .trash),
        ]

        let bodies = CommentDigestStore.approvedBodies(comments)

        #expect(bodies == ["new approved", "old approved"])
    }
}

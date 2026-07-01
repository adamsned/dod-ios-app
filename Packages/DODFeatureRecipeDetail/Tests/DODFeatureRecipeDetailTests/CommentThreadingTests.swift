import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("DUT-392 CommentThreader") struct CommentThreadingTests {

    private func comment(
        id: Int,
        parent: Int? = nil,
        date: TimeInterval
    ) -> RecipeComment {
        RecipeComment(
            id: id,
            postID: 1,
            parentID: parent,
            authorName: "A\(id)",
            avatarURL: nil,
            dateGMT: Date(timeIntervalSince1970: date),
            body: "b\(id)",
            ratingValue: nil,
            status: .approved
        )
    }

    @Test func replyNestsDirectlyBeneathItsParentEvenThoughItIsNewer() {
        // Flat newest-first would put the reply (id 2, newer) ABOVE its parent
        // (id 1, older). Threaded order must place the parent first, reply after.
        let flat = [comment(id: 2, parent: 1, date: 200), comment(id: 1, date: 100)]
        let threaded = CommentThreader.thread(flat)
        #expect(threaded.map(\.comment.id) == [1, 2])
        #expect(threaded.map(\.isReply) == [false, true])
    }

    @Test func topLevelNewestFirstRepliesOldestFirst() {
        let flat = [
            comment(id: 1, date: 100),  // older top-level
            comment(id: 2, date: 400),  // newer top-level
            comment(id: 3, parent: 2, date: 500),  // reply, newer
            comment(id: 4, parent: 2, date: 450),  // reply, older
        ]
        let threaded = CommentThreader.thread(flat)
        // Top-level newest-first (2 then 1); 2's replies oldest-first (4 then 3).
        #expect(threaded.map(\.comment.id) == [2, 4, 3, 1])
    }

    @Test func orphanReplyIsHoistedToTopLevelNotDropped() {
        // Parent 99 isn't in the loaded set → the reply is treated as top-level.
        let flat = [comment(id: 5, parent: 99, date: 300), comment(id: 1, date: 100)]
        let threaded = CommentThreader.thread(flat)
        #expect(Set(threaded.map(\.comment.id)) == [1, 5])
        #expect(threaded.allSatisfy { !$0.isReply })
        // Newest-first among the hoisted top-level set.
        #expect(threaded.map(\.comment.id) == [5, 1])
    }

    @Test func parentIDZeroIsTreatedAsTopLevel() {
        let flat = [comment(id: 1, parent: 0, date: 100)]
        let threaded = CommentThreader.thread(flat)
        #expect(threaded.count == 1)
        #expect(threaded[0].isReply == false)
    }
}

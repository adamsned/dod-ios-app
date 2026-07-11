import Testing

@testable import DODSupport

/// `NewPostsDiff.resolve(latestPostIDs:lastSeen:)` backs the DUT-938
/// background new-post poll: which ids are new since the last poll, and
/// what watermark to persist next.
@Suite("NewPostsDiff.resolve")
struct NewPostsDiffResolveTests {

    @Test func firstRunRecordsBaselineWithoutNotifying() {
        let result = NewPostsDiff.resolve(latestPostIDs: [10, 25, 7], lastSeen: nil)
        #expect(result.toNotify.isEmpty)
        #expect(result.newLastSeen == 25)
    }

    @Test func someNewPostsNotifiesOnlyIDsAboveLastSeenNewestFirst() {
        let result = NewPostsDiff.resolve(latestPostIDs: [18, 20, 25, 30, 22], lastSeen: 20)
        #expect(result.toNotify == [30, 25, 22])
        #expect(result.newLastSeen == 30)
    }

    @Test func noNewPostsLeavesLastSeenUnchanged() {
        let result = NewPostsDiff.resolve(latestPostIDs: [10, 20, 30], lastSeen: 50)
        #expect(result.toNotify.isEmpty)
        #expect(result.newLastSeen == 50)
    }

    @Test func emptyInputWithExistingLastSeenIsANoOp() {
        let result = NewPostsDiff.resolve(latestPostIDs: [], lastSeen: 42)
        #expect(result.toNotify.isEmpty)
        #expect(result.newLastSeen == 42)
    }

    @Test func emptyInputWithNilLastSeenStaysNil() {
        let result = NewPostsDiff.resolve(latestPostIDs: [], lastSeen: nil)
        #expect(result.toNotify.isEmpty)
        #expect(result.newLastSeen == nil)
    }

    @Test func outOfOrderInputIsSortedDescendingInToNotify() {
        let result = NewPostsDiff.resolve(latestPostIDs: [9, 3, 7, 1], lastSeen: 5)
        #expect(result.toNotify == [9, 7])
        #expect(result.newLastSeen == 9)
    }
}

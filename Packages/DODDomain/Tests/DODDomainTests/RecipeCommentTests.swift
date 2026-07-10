import Foundation
import Testing

@testable import DODDomain

// MARK: - Initialization & Equality

@Suite("RecipeComment initialization and equatable") struct RecipeCommentInitTests {
    let testDate = Date(timeIntervalSince1970: 1_609_459_200)

    @Test func initializationWithAllFields() {
        let comment = RecipeComment(
            id: 42,
            postID: 100,
            parentID: 41,
            authorName: "Alice",
            authorEmail: "alice@example.com",
            avatarURL: URL(string: "https://gravatar.com/avatar/abc"),
            dateGMT: testDate,
            body: "Great recipe!",
            ratingValue: 5,
            status: .approved
        )

        #expect(comment.id == 42)
        #expect(comment.postID == 100)
        #expect(comment.parentID == 41)
        #expect(comment.authorName == "Alice")
        #expect(comment.authorEmail == "alice@example.com")
        #expect(comment.avatarURL == URL(string: "https://gravatar.com/avatar/abc"))
        #expect(comment.dateGMT == testDate)
        #expect(comment.body == "Great recipe!")
        #expect(comment.ratingValue == 5)
        #expect(comment.status == .approved)
    }

    @Test func defaultValuesApply() {
        let comment = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Bob",
            dateGMT: testDate,
            body: "Nice!",
            status: .approved
        )

        #expect(comment.id == 1)
        #expect(comment.parentID == nil)
        #expect(comment.authorEmail.isEmpty)
        #expect(comment.avatarURL == nil)
        #expect(comment.ratingValue == nil)
    }

    @Test func identicalCommentsAreEqual() {
        let commentA = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )
        let commentB = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )

        #expect(commentA == commentB)
    }

    @Test func differentIDMakesUnequal() {
        let first = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )
        let second = RecipeComment(
            id: 2,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )
        #expect(first != second)
    }

    @Test func differentPropertyMakesUnequal() {
        let standard = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )
        let differentPostID = RecipeComment(
            id: 1,
            postID: 20,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )
        let differentAuthor = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Bob",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )
        let differentStatus = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .hold
        )

        #expect(standard != differentPostID)
        #expect(standard != differentAuthor)
        #expect(standard != differentStatus)
    }
}

// MARK: - Hashable & Identifiable

@Suite("RecipeComment hashable and identifiable") struct RecipeCommentHashableTests {
    let testDate = Date(timeIntervalSince1970: 1_609_459_200)
    let testDate2 = Date(timeIntervalSince1970: 1_640_995_200)

    @Test func identicalCommentsHaveEqualHashes() {
        let comment = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )
        let copy = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )

        #expect(comment == copy)
        #expect(comment.hashValue == copy.hashValue)
    }

    @Test func hashIsStableAcrossMultipleCalls() {
        let comment = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )
        let hash1 = comment.hashValue
        let hash2 = comment.hashValue
        let hash3 = comment.hashValue

        #expect(hash1 == hash2)
        #expect(hash2 == hash3)
    }

    @Test func commentsCanBeStoredInSet() {
        let comment1 = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test1",
            status: .approved
        )
        let comment2 = RecipeComment(
            id: 2,
            postID: 10,
            authorName: "Bob",
            dateGMT: testDate2,
            body: "Test2",
            status: .hold
        )
        let duplicate = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test1",
            status: .approved
        )

        var set = Set<RecipeComment>()
        set.insert(comment1)
        set.insert(comment2)
        set.insert(duplicate)

        #expect(set.count == 2, "Set should contain only unique comments")
    }

    @Test func idPropertyAndIdentity() {
        let comment = RecipeComment(
            id: 42,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )
        #expect(comment.id == 42)

        let sameID = RecipeComment(
            id: 42,
            postID: 20,
            authorName: "Bob",
            dateGMT: testDate2,
            body: "Other",
            status: .hold
        )
        #expect(comment.id == sameID.id)
        #expect(comment != sameID)
    }

    @Test func extremeIntIDs() {
        let maxID = RecipeComment(
            id: Int.max,
            postID: 10,
            authorName: "A",
            dateGMT: testDate,
            body: "T",
            status: .approved
        )
        let minID = RecipeComment(
            id: Int.min,
            postID: 10,
            authorName: "A",
            dateGMT: testDate,
            body: "T",
            status: .approved
        )
        let zeroID = RecipeComment(
            id: 0,
            postID: 10,
            authorName: "A",
            dateGMT: testDate,
            body: "T",
            status: .approved
        )

        #expect(maxID.id == Int.max)
        #expect(minID.id == Int.min)
        #expect(zeroID.id == 0)
        #expect(maxID != minID)
        #expect(minID != zeroID)
    }
}

// MARK: - Codable

@Suite("RecipeComment codable round-trip") struct RecipeCommentCodableTests {
    let testDate = Date(timeIntervalSince1970: 1_609_459_200)

    @Test func roundTripWithAllFields() throws {
        let original = RecipeComment(
            id: 42,
            postID: 100,
            parentID: 41,
            authorName: "Alice",
            authorEmail: "alice@example.com",
            avatarURL: URL(string: "https://gravatar.com/avatar/abc"),
            dateGMT: testDate,
            body: "Great recipe!",
            ratingValue: 5,
            status: .approved
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecipeComment.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.postID == original.postID)
        #expect(decoded.parentID == original.parentID)
        #expect(decoded.authorName == original.authorName)
        #expect(decoded.authorEmail == original.authorEmail)
        #expect(decoded.avatarURL == original.avatarURL)
        #expect(decoded.dateGMT == original.dateGMT)
        #expect(decoded.body == original.body)
        #expect(decoded.ratingValue == original.ratingValue)
        #expect(decoded.status == original.status)
    }

    @Test func roundTripWithNilOptionals() throws {
        let original = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Simple",
            status: .approved
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecipeComment.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.parentID == nil)
        #expect(decoded.authorEmail.isEmpty)
        #expect(decoded.avatarURL == nil)
        #expect(decoded.ratingValue == nil)
    }

    @Test func dateRoundTripPreservesTimestamp() throws {
        let original = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "Test",
            status: .approved
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecipeComment.self, from: encoded)

        #expect(decoded.dateGMT == original.dateGMT)
    }
}

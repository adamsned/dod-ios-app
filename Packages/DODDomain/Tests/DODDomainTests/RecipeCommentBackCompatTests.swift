import Foundation
import Testing

@testable import DODDomain

// MARK: - Backward Compatibility

@Suite("RecipeComment backward compatibility") struct RecipeCommentBackCompatTests {
    @Test func decodeMissingAuthorEmailDefaultsToEmpty() throws {
        let json = Data(
            """
            {
                "id": 1,
                "postID": 10,
                "authorName": "Alice",
                "dateGMT": 1609459200,
                "body": "Test comment",
                "status": "approved"
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(RecipeComment.self, from: json)
        #expect(decoded.authorEmail.isEmpty)
    }

    @Test func decodeExplicitAuthorEmailPreserved() throws {
        let json = Data(
            """
            {
                "id": 1,
                "postID": 10,
                "authorName": "Alice",
                "authorEmail": "alice@example.com",
                "dateGMT": 1609459200,
                "body": "Test comment",
                "status": "approved"
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(RecipeComment.self, from: json)
        #expect(decoded.authorEmail == "alice@example.com")
    }

    @Test func decodeMissingParentIDDecodesToNil() throws {
        let json = Data(
            """
            {
                "id": 1,
                "postID": 10,
                "authorName": "Alice",
                "dateGMT": 1609459200,
                "body": "Top-level comment",
                "status": "approved"
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(RecipeComment.self, from: json)
        #expect(decoded.parentID == nil)
    }

    @Test func decodeExplicitParentIDPreserved() throws {
        let json = Data(
            """
            {
                "id": 2,
                "postID": 10,
                "parentID": 1,
                "authorName": "Bob",
                "dateGMT": 1609459200,
                "body": "Reply comment",
                "status": "approved"
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(RecipeComment.self, from: json)
        #expect(decoded.parentID == 1)
    }

    @Test func decodeMissingAvatarURLDecodesToNil() throws {
        let json = Data(
            """
            {
                "id": 1,
                "postID": 10,
                "authorName": "Alice",
                "dateGMT": 1609459200,
                "body": "Test",
                "status": "approved"
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(RecipeComment.self, from: json)
        #expect(decoded.avatarURL == nil)
    }

    @Test func decodeMissingRatingValueDecodesToNil() throws {
        let json = Data(
            """
            {
                "id": 1,
                "postID": 10,
                "authorName": "Alice",
                "dateGMT": 1609459200,
                "body": "No rating",
                "status": "approved"
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(RecipeComment.self, from: json)
        #expect(decoded.ratingValue == nil)
    }
}

// MARK: - Status Enum & Edge Cases

@Suite("RecipeComment status enum and edge cases") struct RecipeCommentStatusTests {
    let testDate = Date(timeIntervalSince1970: 1_609_459_200)

    @Test func allKnownStatusesCodeAndDecode() throws {
        let statuses: [RecipeComment.Status] = [.approved, .hold, .spam, .trash]

        for status in statuses {
            let comment = RecipeComment(
                id: 1,
                postID: 10,
                authorName: "Alice",
                dateGMT: testDate,
                body: "Test",
                status: status
            )

            let encoded = try JSONEncoder().encode(comment)
            let decoded = try JSONDecoder().decode(RecipeComment.self, from: encoded)

            #expect(decoded.status == status)
        }
    }

    @Test func emptyAuthorName() {
        let comment = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "",
            dateGMT: testDate,
            body: "Anonymous comment",
            status: .approved
        )

        #expect(comment.authorName.isEmpty)
    }

    @Test func emptyBody() {
        let comment = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: "",
            status: .approved
        )

        #expect(comment.body.isEmpty)
    }

    @Test func ratingValueRange1to5() {
        for rating in 1...5 {
            let comment = RecipeComment(
                id: 1,
                postID: 10,
                authorName: "Alice",
                dateGMT: testDate,
                body: "Test",
                ratingValue: rating,
                status: .approved
            )
            #expect(comment.ratingValue == rating)
        }
    }

    @Test func differentDates() {
        let pastDate = Date(timeIntervalSince1970: 0)
        let futureDate = Date(timeIntervalSince1970: 2_147_483_647)

        let pastComment = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: pastDate,
            body: "Old",
            status: .approved
        )

        let futureComment = RecipeComment(
            id: 2,
            postID: 10,
            authorName: "Bob",
            dateGMT: futureDate,
            body: "Future",
            status: .approved
        )

        #expect(pastComment.dateGMT < futureComment.dateGMT)
        #expect(pastComment != futureComment)
    }

    @Test func complexBodyWithHTML() throws {
        let body = "<p>This has <strong>HTML</strong> entities &amp; stuff</p>"
        let comment = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "Alice",
            dateGMT: testDate,
            body: body,
            status: .approved
        )

        let encoded = try JSONEncoder().encode(comment)
        let decoded = try JSONDecoder().decode(RecipeComment.self, from: encoded)

        #expect(decoded.body == body)
    }

    @Test func allStatusVariantsInSingleComparison() {
        let approved = RecipeComment(
            id: 1,
            postID: 10,
            authorName: "A",
            dateGMT: testDate,
            body: "T",
            status: .approved
        )
        let hold = RecipeComment(
            id: 2,
            postID: 10,
            authorName: "A",
            dateGMT: testDate,
            body: "T",
            status: .hold
        )
        let spam = RecipeComment(
            id: 3,
            postID: 10,
            authorName: "A",
            dateGMT: testDate,
            body: "T",
            status: .spam
        )
        let trash = RecipeComment(
            id: 4,
            postID: 10,
            authorName: "A",
            dateGMT: testDate,
            body: "T",
            status: .trash
        )

        let comments = [approved, hold, spam, trash]
        let statusSet = Set(comments.map(\.status))

        #expect(statusSet.count == 4)
        #expect(statusSet.contains(.approved))
        #expect(statusSet.contains(.hold))
        #expect(statusSet.contains(.spam))
        #expect(statusSet.contains(.trash))
    }
}

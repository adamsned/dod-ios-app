import DODDomain
import Foundation
import Testing

@testable import DODNetworking

@Suite("WPCommentsClient.comments") struct WPCommentsClientGetTests {

    @Test func decodesCommentsPageWithEmbeddedAuthor() async throws {
        let data = try loadFixture("comments-page1")
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: data)
        let client = WPCommentsClient(httpClient: fake)

        let page = try await client.comments(forPostID: 21238)

        #expect(!page.comments.isEmpty, "Fixture should yield at least one comment")
        let first = try #require(page.comments.first)
        #expect(first.postID == 21238)
        #expect(!first.authorName.isEmpty)
        #expect(first.avatarURL != nil, "Real WP responses always include author_avatar_urls")
        #expect(first.status == .approved)
        // Body is plain text (no HTML tags after sanitization).
        #expect(!first.body.contains("<p>"))
        #expect(!first.body.contains("<img"))
        // Captured GET sends _embed=author + orderby=date + order=desc.
        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("post=21238"))
        #expect(url.contains("_embed=author"))
        #expect(url.contains("orderby=date"))
        #expect(url.contains("order=desc"))
    }

    @Test func parsesWPRMCommentRatingMeta() async throws {
        let synthetic = #"""
            [{
              "id": 1, "post": 21238, "parent": 0,
              "author_name": "Test User",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "<p>Great recipe.</p>" },
              "status": "approved",
              "meta": { "wprm_comment_rating": 5 }
            }]
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(synthetic.utf8))
        let client = WPCommentsClient(httpClient: fake)

        let page = try await client.comments(forPostID: 21238)
        let comment = try #require(page.comments.first)
        #expect(comment.ratingValue == 5)
    }

    @Test func parsesWPRMCommentRatingFromString() async throws {
        // Some WP meta registrations serialize integers as strings.
        let synthetic = #"""
            [{
              "id": 1, "post": 21238, "parent": 0,
              "author_name": "T",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "ok" },
              "status": "approved",
              "meta": { "wprm_comment_rating": "4" }
            }]
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(synthetic.utf8))
        let client = WPCommentsClient(httpClient: fake)

        let page = try await client.comments(forPostID: 21238)
        #expect(page.comments.first?.ratingValue == 4)
    }

    @Test func paginationHeadersAreRead() async throws {
        let body = Data("[]".utf8)
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments") { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json",
                    "X-WP-Total": "42",
                    "X-WP-TotalPages": "5",
                ]
            )
            guard let response else {
                throw WPClientError.underlying(message: "Could not synthesize response")
            }
            return (body, response)
        }
        let client = WPCommentsClient(httpClient: fake)

        let page = try await client.comments(forPostID: 1)
        #expect(page.totalCount == 42)
        #expect(page.totalPages == 5)
    }

    @Test func parentZeroNormalizesToNil() async throws {
        let synthetic = #"""
            [{
              "id": 1, "post": 21238, "parent": 0,
              "author_name": "T",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "x" },
              "status": "approved",
              "meta": {}
            }]
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(synthetic.utf8))
        let client = WPCommentsClient(httpClient: fake)

        let page = try await client.comments(forPostID: 21238)
        #expect(page.comments.first?.parentID == nil)
    }

    @Test func unknownStatusDecodesToUnknown() async throws {
        let synthetic = #"""
            [{
              "id": 1, "post": 21238, "parent": 0,
              "author_name": "T",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "x" },
              "status": "futureValue",
              "meta": {}
            }]
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(synthetic.utf8))
        let client = WPCommentsClient(httpClient: fake)

        let page = try await client.comments(forPostID: 21238)
        #expect(page.comments.first?.status == .unknown)
    }
}

@Suite("WPCommentsClient.postComment") struct WPCommentsClientPostTests {

    @Test func postCommentSendsCorrectBody() async throws {
        let responseBody = #"""
            {
              "id": 999, "post": 21238, "parent": 0,
              "author_name": "Reviewer",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "<p>Tasty.</p>" },
              "status": "hold",
              "meta": { "wprm_comment_rating": 5 }
            }
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(responseBody.utf8), statusCode: 201)
        let client = WPCommentsClient(httpClient: fake)

        let comment = try await client.postComment(
            postID: 21238,
            authorName: "Reviewer",
            authorEmail: "r@example.com",
            content: "Tasty.",
            ratingValue: 5
        )

        // Round-trip the request body through JSONSerialization so we can
        // assert each field without caring about JSON key ordering.
        let captured = await fake.capturedRequests
        let request = try #require(captured.first)
        let body = try #require(request.httpBody)
        let json = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        #expect(json["post"] as? Int == 21238)
        #expect(json["author_name"] as? String == "Reviewer")
        #expect(json["author_email"] as? String == "r@example.com")
        #expect(json["content"] as? String == "Tasty.")
        let meta = try #require(json["meta"] as? [String: Any])
        #expect(meta["wprm_comment_rating"] as? Int == 5)
        // Returned RecipeComment reflects the WP response.
        #expect(comment.id == 999)
        #expect(comment.ratingValue == 5)
    }

    @Test func postCommentParsesHoldStatus() async throws {
        let responseBody = #"""
            {
              "id": 1, "post": 1, "parent": 0,
              "author_name": "Pending",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "ok" },
              "status": "hold",
              "meta": {}
            }
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(responseBody.utf8), statusCode: 201)
        let client = WPCommentsClient(httpClient: fake)

        let comment = try await client.postComment(
            postID: 1,
            authorName: "Pending",
            authorEmail: "p@example.com",
            content: "ok"
        )
        #expect(comment.status == .hold)
    }

    @Test func postCommentOmitsMetaWhenRatingNil() async throws {
        let responseBody = #"""
            {
              "id": 1, "post": 1, "parent": 0,
              "author_name": "T",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "ok" },
              "status": "approved",
              "meta": {}
            }
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(responseBody.utf8), statusCode: 201)
        let client = WPCommentsClient(httpClient: fake)

        _ = try await client.postComment(
            postID: 1,
            authorName: "T",
            authorEmail: "t@example.com",
            content: "ok"
        )

        let captured = await fake.capturedRequests
        let body = try #require(captured.first?.httpBody)
        let json = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        #expect(json["meta"] == nil)
    }

    @Test func outOfRangeRatingThrows() async throws {
        let fake = FakeHTTPClient()
        let client = WPCommentsClient(httpClient: fake)
        await #expect(throws: WPClientError.self) {
            _ = try await client.postComment(
                postID: 1,
                authorName: "T",
                authorEmail: "t@example.com",
                content: "x",
                ratingValue: 6
            )
        }
    }

    @Test func httpErrorStatusThrows() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data("{}".utf8), statusCode: 500)
        let client = WPCommentsClient(httpClient: fake)
        await #expect(throws: WPClientError.httpStatus(500)) {
            _ = try await client.postComment(
                postID: 1,
                authorName: "T",
                authorEmail: "t@example.com",
                content: "x"
            )
        }
    }
}

// MARK: - helpers

private func loadFixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle.module.url(forResource: name, withExtension: "json"),
        "Fixture \(name).json not found in test bundle"
    )
    return try Data(contentsOf: url)
}

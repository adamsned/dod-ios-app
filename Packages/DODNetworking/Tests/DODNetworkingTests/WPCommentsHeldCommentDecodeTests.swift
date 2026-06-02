import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// DUT-27: a freshly-posted comment is HELD for moderation, and WordPress
/// serializes its empty meta as an empty JSON array (meta: []) rather than an
/// object. The comment-create (201) response must still decode - it previously
/// threw WPClientError.decoding, so the app showed "Couldn't read the server's
/// reply" and never ran the success path even though the comment had posted.
/// These drive `postComment` through a stub returning the held-comment shape and
/// assert it decodes (no throw) and routes to a `.hold` domain comment.
struct WPCommentsHeldCommentDecodeTests {

    private func postHeldComment(_ json: String) async throws -> RecipeComment {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(json.utf8), statusCode: 201)
        let client = WPCommentsClient(httpClient: fake)
        return try await client.postComment(
            postID: 21238,
            authorName: "Ned",
            authorEmail: "ned@example.com",
            content: "Awesome, I love this cake so much!"
        )
    }

    @Test func decodesHeldCommentWithEmptyArrayMeta() async throws {
        let json = """
            {"id":7001,"post":21238,"parent":0,"author":0,"author_name":"Ned",\
            "date_gmt":"2026-06-01T19:12:00",\
            "content":{"rendered":"<p>Awesome, I love this cake so much!</p>"},\
            "status":"hold",\
            "author_avatar_urls":{"96":"https://secure.gravatar.com/avatar/x?s=96"},\
            "meta":[]}
            """
        let comment = try await postHeldComment(json)
        #expect(comment.status == .hold)
        #expect(comment.body == "Awesome, I love this cake so much!")
        #expect(comment.ratingValue == nil)
    }

    @Test func decodesHeldCommentWithObjectMetaRating() async throws {
        let json = """
            {"id":7002,"post":21238,"author_name":"Ned",\
            "content":{"rendered":"<p>Great</p>"},\
            "status":"hold","meta":{"wprm_comment_rating":5}}
            """
        let comment = try await postHeldComment(json)
        #expect(comment.status == .hold)
        #expect(comment.ratingValue == 5)
    }

    @Test func decodesHeldCommentWithMissingContentAndArrayMeta() async throws {
        let json = """
            {"id":7003,"post":21238,"author_name":"Ned","status":"hold","meta":[]}
            """
        let comment = try await postHeldComment(json)
        #expect(comment.status == .hold)
        #expect(comment.body.isEmpty)
        #expect(comment.ratingValue == nil)
    }
}

import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// Regression coverage: `meta.wprm_comment_rating` can arrive as a
/// decimal-formatted numeric STRING (e.g. `"4.0"`), not just a bare Int or a
/// plain-integer string (`"4"`) — some WP meta registrations format the value
/// this way. `Int("4.0")` returns `nil` in Swift, so the naive `Int(stringValue)`
/// fast path alone silently dropped an otherwise-valid star rating to `nil`
/// instead of decoding it as `4`. `CommentMeta`'s decoder now falls back to
/// `Double(stringValue)?.rounded()` when the plain `Int` parse fails.
@Suite("WPCommentsClient decimal-string wprm_comment_rating (regression)")
struct WPCommentsClientDecimalRatingStringTests {

    /// The regression case: before the fix, `"4.0"` decoded to `ratingValue == nil`.
    @Test func decimalRatingStringDecodesToRoundedInt() async throws {
        let synthetic = #"""
            [{
              "id": 1, "post": 21238, "parent": 0,
              "author_name": "John Doe",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "Great recipe!" },
              "status": "approved",
              "meta": { "wprm_comment_rating": "4.0" }
            }]
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(synthetic.utf8))
        let client = WPCommentsClient(httpClient: fake)

        let page = try await client.comments(forPostID: 21238)
        let comment = try #require(page.comments.first)
        #expect(comment.ratingValue == 4)
    }

    /// Adjacent edge case: a non-whole decimal string still rounds to the
    /// nearest Int rather than truncating or being dropped.
    @Test func nonWholeDecimalRatingStringRoundsToNearestInt() async throws {
        let synthetic = #"""
            [{
              "id": 1, "post": 21238, "parent": 0,
              "author_name": "John Doe",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "Great recipe!" },
              "status": "approved",
              "meta": { "wprm_comment_rating": "3.6" }
            }]
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(synthetic.utf8))
        let client = WPCommentsClient(httpClient: fake)

        let page = try await client.comments(forPostID: 21238)
        let comment = try #require(page.comments.first)
        #expect(comment.ratingValue == 4)
    }

    /// Not a regression: the plain-integer string fast path ("5", no decimal
    /// point) must keep working exactly as before.
    @Test func plainIntegerRatingStringStillDecodesCorrectly() async throws {
        let synthetic = #"""
            [{
              "id": 1, "post": 21238, "parent": 0,
              "author_name": "John Doe",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "Great recipe!" },
              "status": "approved",
              "meta": { "wprm_comment_rating": "5" }
            }]
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(synthetic.utf8))
        let client = WPCommentsClient(httpClient: fake)

        let page = try await client.comments(forPostID: 21238)
        let comment = try #require(page.comments.first)
        #expect(comment.ratingValue == 5)
    }
}

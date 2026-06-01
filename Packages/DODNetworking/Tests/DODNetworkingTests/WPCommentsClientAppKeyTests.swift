import Foundation
import Testing

@testable import DODNetworking

/// DUT-23: the comment POST must carry the `X-DOD-App-Key` app-identity header
/// when an app key is provisioned — so WordPress's
/// `rest_allow_anonymous_comments` filter accepts the app's anonymous comment —
/// and must omit it when no key is present (dev / PR builds, or an empty value).
/// This header is the client half of the secret-gated anonymous-comment path; a
/// silent regression would break posting in the shipped build, so both
/// directions are pinned.
struct WPCommentsClientAppKeyTests {

    /// Drive `postComment` through a `FakeHTTPClient` and return the captured
    /// POST `URLRequest`. The stub returns 201 with a body that does NOT decode
    /// to a comment; that is fine — the fake records the request before
    /// `postComment` attempts to decode, so the header assertion is independent
    /// of the response shape.
    private func capturedPOST(appKey: String?) async throws -> URLRequest {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data("{}".utf8), statusCode: 201)
        let client = WPCommentsClient(httpClient: fake, appKey: appKey)
        _ = try? await client.postComment(
            postID: 21238,
            authorName: "Dani",
            authorEmail: "dani@example.com",
            content: "Great recipe"
        )
        return try #require(await fake.capturedRequests.first { $0.httpMethod == "POST" })
    }

    @Test func sendsAppKeyHeaderWhenProvided() async throws {
        let posted = try await capturedPOST(appKey: "test-secret-123")
        #expect(posted.value(forHTTPHeaderField: "X-DOD-App-Key") == "test-secret-123")
    }

    @Test func omitsAppKeyHeaderWhenAbsent() async throws {
        let posted = try await capturedPOST(appKey: nil)
        #expect(posted.value(forHTTPHeaderField: "X-DOD-App-Key") == nil)
    }

    @Test func treatsEmptyAppKeyAsAbsent() async throws {
        let posted = try await capturedPOST(appKey: "")
        #expect(posted.value(forHTTPHeaderField: "X-DOD-App-Key") == nil)
    }
}

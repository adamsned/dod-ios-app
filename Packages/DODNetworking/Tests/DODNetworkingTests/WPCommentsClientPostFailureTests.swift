import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// DUT-7 (US-14 / AC-14.4): the comment POST must never fail silently. Every
/// non-2xx surfaces a typed error that carries the status — and, when
/// WordPress returns one, the human-readable reason — so the view-model
/// snackbar can tell the user *why* and an on-device reporter can pin the
/// hypothesis. Plus hypothesis #4: the client refuses to POST an empty author
/// name/email (which WP 400s) so a fresh-install Keychain miss can't produce
/// the "tap, nothing happens" report.
///
/// All coverage stays at L1/L2 against ``FakeHTTPClient`` — no write ever
/// reaches the live blog (constitution §6). Extracted from
/// `WPCommentsClientTests.swift` to keep that file under the SwiftLint
/// `file_length` cap.
@Suite("WPCommentsClient.postComment — DUT-7 failure surfacing + guards")
struct WPCommentsClientPostFailureTests {

    /// WP rejects with a JSON error body → we surface status + message.
    @Test func wpErrorBodyIsSurfacedWithStatusAndMessage() async throws {
        let errorBody = #"""
            {"code":"rest_comment_content_invalid","message":"Comment content is invalid.","data":{"status":400}}
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data(errorBody.utf8), statusCode: 400)
        let client = WPCommentsClient(httpClient: fake)

        await #expect(
            throws: WPClientError.httpStatusWithBody(400, message: "Comment content is invalid.")
        ) {
            _ = try await client.postComment(
                postID: 1,
                authorName: "T",
                authorEmail: "t@example.com",
                content: "x"
            )
        }
    }

    /// A Wordfence-style HTML challenge (403, no JSON) still surfaces a
    /// tag-stripped snippet rather than collapsing to a bare code.
    @Test func htmlSecurityChallengeBodyIsStrippedAndSurfaced() async throws {
        let html = "<html><body><h1>Access Denied</h1><p>Your request was blocked.</p></body></html>"
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", html: html, statusCode: 403)
        let client = WPCommentsClient(httpClient: fake)

        do {
            _ = try await client.postComment(
                postID: 1,
                authorName: "T",
                authorEmail: "t@example.com",
                content: "x"
            )
            Issue.record("Expected a 403 to throw")
        } catch let WPClientError.httpStatusWithBody(code, message) {
            #expect(code == 403)
            #expect(!message.contains("<"), "HTML tags must be stripped")
            #expect(message.contains("Access Denied"))
        }
    }

    /// 401 / 403 / 422 with no usable message body fall back to the
    /// status-only case — each still distinct + non-silent.
    @Test(arguments: [401, 403, 422])
    func bodylessNon2xxFallsBackToStatusOnly(_ status: Int) async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments", json: Data("".utf8), statusCode: status)
        let client = WPCommentsClient(httpClient: fake)

        await #expect(throws: WPClientError.httpStatus(status)) {
            _ = try await client.postComment(
                postID: 1,
                authorName: "T",
                authorEmail: "t@example.com",
                content: "x"
            )
        }
    }

    /// Hypothesis #4: an empty email must be refused before the request fires
    /// (WP would 400 it), and the captured request list proves nothing was
    /// sent.
    @Test func emptyAuthorEmailIsRejectedBeforePOST() async throws {
        let fake = FakeHTTPClient()
        let client = WPCommentsClient(httpClient: fake)

        await #expect(throws: WPClientError.self) {
            _ = try await client.postComment(
                postID: 1,
                authorName: "Real Name",
                authorEmail: "   ",
                content: "x"
            )
        }
        let captured = await fake.capturedRequests
        #expect(captured.isEmpty, "No POST should reach the network with an empty email")
    }

    @Test func emptyAuthorNameIsRejectedBeforePOST() async throws {
        let fake = FakeHTTPClient()
        let client = WPCommentsClient(httpClient: fake)

        await #expect(throws: WPClientError.self) {
            _ = try await client.postComment(
                postID: 1,
                authorName: "",
                authorEmail: "real@example.com",
                content: "x"
            )
        }
        let captured = await fake.capturedRequests
        #expect(captured.isEmpty, "No POST should reach the network with an empty name")
    }

    // MARK: - extractWPErrorMessage unit coverage

    @Test func extractsMessageFromWPJSONError() {
        let data = Data(#"{"code":"x","message":"Spam detected.","data":{"status":403}}"#.utf8)
        #expect(WPCommentsClient.extractWPErrorMessage(from: data) == "Spam detected.")
    }

    @Test func extractReturnsNilForEmptyBody() {
        #expect(WPCommentsClient.extractWPErrorMessage(from: Data()) == nil)
    }

    @Test func extractReturnsNilForJSONWithBlankMessage() {
        let data = Data(#"{"code":"x","message":"   ","data":{"status":400}}"#.utf8)
        #expect(WPCommentsClient.extractWPErrorMessage(from: data) == nil)
    }

    @Test func extractClampsLongHTMLBody() {
        let long = "<p>" + String(repeating: "A", count: 500) + "</p>"
        let result = WPCommentsClient.extractWPErrorMessage(from: Data(long.utf8))
        let unwrapped = try? #require(result)
        #expect((unwrapped?.count ?? 999) <= 140)
    }
}

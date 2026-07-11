import Foundation
import Testing

@testable import DODNetworking

/// DUT-397 (`WPRestClient.parseTotalPages`) documents the contract for the
/// `X-WP-TotalPages` header: "default to 1 when absent or unparseable", and a
/// *present* `"0"` must still clamp to 1 rather than return the
/// self-contradictory "page 1 of 0" — WordPress's own comments controller
/// computes this header as `ceil(total / per_page)`, which is literally `0`
/// for a post with zero comments. `WPCommentsClient` parses the identical
/// header with its own `parseHeader` helper instead of
/// `WPRestClient.parseTotalPages` and never got the DUT-397 clamp, so a
/// zero-comment post's `CommentsPage.totalPages` came back `0` instead of
/// `1`, breaking any "page N of totalPages" / `page < totalPages` gating a
/// caller builds on top of it.
@Suite("WPCommentsClient.comments totalPages clamp (DUT-397 parity)")
struct WPCommentsClientTotalPagesTests {

    private func stubbedClient(totalPagesHeader: String?, totalHeader: String? = nil) async -> WPCommentsClient {
        let body = Data("[]".utf8)
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "comments") { request in
            var headers = ["Content-Type": "application/json"]
            if let totalPagesHeader { headers["X-WP-TotalPages"] = totalPagesHeader }
            if let totalHeader { headers["X-WP-Total"] = totalHeader }
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )
            guard let response else {
                throw WPClientError.underlying(message: "Could not synthesize response")
            }
            return (body, response)
        }
        return WPCommentsClient(httpClient: fake)
    }

    @Test func clampsPresentZeroTotalPagesHeaderToOne() async throws {
        let client = await stubbedClient(totalPagesHeader: "0", totalHeader: "0")

        let page = try await client.comments(forPostID: 1)
        #expect(page.totalCount == 0, "A genuinely empty thread's total count of 0 is correct as-is")
        #expect(page.totalPages == 1, "totalPages must clamp to 1 even when WP sends a literal 0")
    }

    @Test func clampsNegativeTotalPagesHeaderToOne() async throws {
        let client = await stubbedClient(totalPagesHeader: "-2")

        let page = try await client.comments(forPostID: 1)
        #expect(page.totalPages == 1)
    }

    @Test func defaultsToOneWhenTotalPagesHeaderAbsent() async throws {
        let client = await stubbedClient(totalPagesHeader: nil)

        let page = try await client.comments(forPostID: 1)
        #expect(page.totalPages == 1)
    }

    @Test func defaultsToOneWhenTotalPagesHeaderUnparseable() async throws {
        let client = await stubbedClient(totalPagesHeader: "not-a-number")

        let page = try await client.comments(forPostID: 1)
        #expect(page.totalPages == 1)
    }

    @Test func preservesAPresentPositiveTotalPagesHeader() async throws {
        let client = await stubbedClient(totalPagesHeader: "7")

        let page = try await client.comments(forPostID: 1)
        #expect(page.totalPages == 7)
    }
}

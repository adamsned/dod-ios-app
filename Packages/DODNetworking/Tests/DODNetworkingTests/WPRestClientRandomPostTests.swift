import Foundation
import Testing

@testable import DODNetworking

/// DUT-1062 (fixed): "Surprise Me" pulls one uniformly-random RECIPE from the
/// whole catalog. The pre-fix implementation asked WP for `orderby=rand`, which
/// core WP REST rejects (HTTP 400), so every tap silently fell back to the
/// in-memory sample and old recipes never surfaced. `randomPost()` now counts
/// the `wprm_recipe` set (`X-WP-Total`), rolls a random `offset`, and resolves
/// that recipe's `wprm_parent_post_id` through the existing `post(id:)` path.
@Suite("WPRestClient.randomPost") struct WPRestClientRandomPostTests {

    private let singlePostFixture = """
        {
          "id": 21238,
          "slug": "garlic-butter-skillet-corn",
          "link": "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/",
          "title": { "rendered": "Garlic Butter Skillet Corn" },
          "excerpt": { "rendered": "<p>Easy 15-minute side dish.</p>" },
          "date": "2026-05-01T10:00:00",
          "featured_media": 23019,
          "categories": [1590, 334]
        }
        """

    /// A `wprm_recipe` offset row pointing at post 21238 (parent id is a STRING
    /// on the wire, as WP Recipe Maker returns it).
    private let offsetPointingAt21238 = #"[{"wprm_parent_post_id":"21238"}]"#

    /// Build a client wired for the 3-step random-recipe flow. `total` is the
    /// `X-WP-Total` count header (nil = header absent); `offsetBody` is the
    /// `wprm_recipe?offset=` response; `postJSON` + `postStatus` back the
    /// `post(id:)` resolution; `countStatus` lets a test fail the count probe.
    private func makeClient(
        total: String?,
        offsetBody: String,
        postJSON: String? = nil,
        postStatus: Int = 200,
        countStatus: Int = 200
    ) async -> (WPRestClient, FakeHTTPClient) {
        let fake = FakeHTTPClient()
        // Registered first so the offset fetch (its URL also contains
        // "wprm_recipe") matches here before the count route below.
        await fake.stub(urlContaining: "offset=", json: Data(offsetBody.utf8))
        // The count probe: return X-WP-Total (when provided) on a per_page=1 GET.
        await fake.stub(urlContaining: "wprm_recipe") { request in
            var headers = ["Content-Type": "application/json"]
            if let total { headers["X-WP-Total"] = total }
            guard
                let response = HTTPURLResponse(
                    url: request.url ?? URL(filePath: "/"),
                    statusCode: countStatus,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                )
            else {
                throw WPClientError.underlying(message: "Could not synthesize response")
            }
            return (Data(#"[{"id":1}]"#.utf8), response)
        }
        await fake.stub(urlContaining: "posts/", json: Data((postJSON ?? "{}").utf8), statusCode: postStatus)
        return (WPRestClient(httpClient: fake), fake)
    }

    @Test func resolvesARandomRecipeToItsParentPost() async throws {
        let (client, _) = await makeClient(
            total: "259",
            offsetBody: offsetPointingAt21238,
            postJSON: singlePostFixture
        )
        let item = try await client.randomPost()
        #expect(item.id == 21238)
        #expect(item.title == "Garlic Butter Skillet Corn")
        // The canonical URL comes from the resolved POST, so a Surprise item is
        // byte-identical to a normal feed tap (the detail screen keys off it).
        #expect(item.canonicalURL?.absoluteString == "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/")
    }

    @Test func samplesTheRecipeCPTByOffsetNeverOrderbyRand() async throws {
        let (client, fake) = await makeClient(
            total: "259",
            offsetBody: offsetPointingAt21238,
            postJSON: singlePostFixture
        )
        _ = try await client.randomPost()
        let urls = await fake.capturedRequests.compactMap { $0.url?.absoluteString }
        // Never the broken parameter that WP rejects with a 400.
        #expect(!urls.contains { $0.contains("orderby=rand") })
        // Samples the recipe CPT at a random offset for just the parent id.
        #expect(urls.contains { $0.contains("wprm_recipe") && $0.contains("offset=") })
        #expect(urls.contains { $0.contains("wprm_parent_post_id") })
        // Resolves via the existing single-post path.
        #expect(urls.contains { $0.contains("posts/21238") })
    }

    @Test func missingTotalCountHeaderThrowsUnderlying() async {
        let (client, _) = await makeClient(total: nil, offsetBody: offsetPointingAt21238)
        await #expect {
            _ = try await client.randomPost()
        } throws: { error in
            guard case .underlying = error as? WPClientError else { return false }
            return true
        }
    }

    @Test func countProbeHTTPErrorPropagates() async {
        let (client, _) = await makeClient(
            total: "259",
            offsetBody: offsetPointingAt21238,
            countStatus: 500
        )
        await #expect(throws: WPClientError.httpStatus(500)) {
            _ = try await client.randomPost()
        }
    }

    @Test func emptyOffsetSlotsRerollThenThrow() async throws {
        let (client, fake) = await makeClient(total: "259", offsetBody: "[]")
        await #expect {
            _ = try await client.randomPost()
        } throws: { error in
            guard case .underlying = error as? WPClientError else { return false }
            return true
        }
        // One count probe + four offset attempts (the reroll budget).
        let offsetHits = await fake.capturedRequests
            .compactMap { $0.url?.absoluteString }
            .filter { $0.contains("offset=") }
        #expect(offsetHits.count == 4)
    }

    @Test func orphanedRecipeRerollsThenThrows() async {
        let (client, _) = await makeClient(
            total: "259",
            offsetBody: #"[{"wprm_parent_post_id":"0"}]"#
        )
        await #expect {
            _ = try await client.randomPost()
        } throws: { error in
            guard case .underlying = error as? WPClientError else { return false }
            return true
        }
    }

    @Test func unpublishedParentPostRerollsThenThrows() async {
        let (client, _) = await makeClient(
            total: "259",
            offsetBody: offsetPointingAt21238,
            postJSON: "{}",
            postStatus: 404
        )
        await #expect {
            _ = try await client.randomPost()
        } throws: { error in
            guard case .underlying = error as? WPClientError else { return false }
            return true
        }
    }

    @Test func rerollRecoversAfterAnOrphanedSlot() async throws {
        // First offset attempt is an orphan (no parent), the next resolves —
        // proving the reroll RECOVERS rather than only failing out.
        let fake = FakeHTTPClient()
        let attempts = OffsetAttemptCounter()
        let orphan = #"[{"wprm_parent_post_id":"0"}]"#
        let good = offsetPointingAt21238
        await fake.stub(urlContaining: "offset=") { request in
            let attempt = await attempts.next()
            let body = attempt == 1 ? orphan : good
            guard
                let response = HTTPURLResponse(
                    url: request.url ?? URL(filePath: "/"),
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )
            else {
                throw WPClientError.underlying(message: "no response")
            }
            return (Data(body.utf8), response)
        }
        await fake.stub(urlContaining: "wprm_recipe") { request in
            guard
                let response = HTTPURLResponse(
                    url: request.url ?? URL(filePath: "/"),
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["X-WP-Total": "259", "Content-Type": "application/json"]
                )
            else {
                throw WPClientError.underlying(message: "no response")
            }
            return (Data(#"[{"id":1}]"#.utf8), response)
        }
        await fake.stub(urlContaining: "posts/", json: Data(singlePostFixture.utf8))
        let client = WPRestClient(httpClient: fake)
        let item = try await client.randomPost()
        #expect(item.id == 21238)
    }
}

/// Serializes the offset-fetch attempt index for the reroll-recovery test.
private actor OffsetAttemptCounter {
    private var count = 0
    func next() -> Int {
        count += 1
        return count
    }
}

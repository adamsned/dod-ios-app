import Foundation
import Testing

@testable import DODNetworking

// MARK: - WPRestClient+Posts edge cases and lossy decode for post(slug:)

/// Edge-case coverage for WPRestClient+Posts methods beyond the happy-path tests
/// in WPRestClientTests.swift. Focuses on lossy decode for post(slug:),
/// postsPage() tuple return validation, search whitespace behavior, and
/// default parameter verification.
@Suite("WPRestClient.posts edge cases") struct WPRestClientPostsEdgeCasesTests {

    // MARK: - post(slug:) lossy decode (post-specific, unlike posts/search)

    /// post(slug:) uses LossyArray like posts() and search(), but the method
    /// wasn't covered in WPPostLossyDecodeTests. A malformed post in the
    /// response (alongside a good match) must not nuke the slug lookup.
    @Test func postSlugSkipsMalformedPostWhenGoodOnePresent() async throws {
        let fake = FakeHTTPClient()
        let response = """
            [
              {
                "id": 100,
                "slug": "target-post",
                "link": "https://www.dutchovendaddy.com/target-post/",
                "title": { "rendered": "Target Post" },
                "excerpt": { "rendered": "<p>Found it.</p>" },
                "date": "2026-05-01T10:00:00",
                "categories": []
              },
              {
                "id": 101,
                "slug": "malformed-post",
                "title": null,
                "excerpt": { "rendered": "<p>Broken.</p>" }
              }
            ]
            """
        await fake.stub(urlContaining: "posts", json: Data(response.utf8))
        let client = WPRestClient(httpClient: fake)

        let item = try await client.post(slug: "target-post")

        #expect(item?.id == 100)
        #expect(item?.title == "Target Post")
        #expect(item?.excerpt == "Found it.")
    }

    /// Verify that post(slug:) returns nil when zero posts match (not just
    /// when array is empty, but when the slug lookup specifically finds no match).
    @Test func postSlugReturnsNilWhenArrayEmpty() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)

        let item = try await client.post(slug: "nonexistent")

        #expect(item == nil)
    }

    // MARK: - postsPage() tuple return (totalPages verification)

    /// postsPage() returns a tuple (items, totalPages). Verify the totalPages
    /// value is correctly extracted from X-WP-TotalPages header and included
    /// in the return value (not just parsed, but threaded through).
    @Test func postsPageReturnsTupleWithCorrectTotalPages() async throws {
        let fake = FakeHTTPClient()
        let fixture = """
            [
              {
                "id": 1,
                "slug": "page-one",
                "link": "https://www.dutchovendaddy.com/page-one/",
                "title": { "rendered": "Page One" },
                "excerpt": { "rendered": "<p>First page.</p>" },
                "date": "2026-05-01T10:00:00",
                "categories": []
              }
            ]
            """
        // Stub with handler to control the X-WP-TotalPages response header
        await fake.stub(urlContaining: "posts") { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json", "X-WP-TotalPages": "42"]
            )
            guard let response else {
                throw WPClientError.underlying(message: "Failed to synthesize response")
            }
            return (Data(fixture.utf8), response)
        }
        let client = WPRestClient(httpClient: fake)

        let (items, totalPages) = try await client.postsPage()

        #expect(items.count == 1)
        #expect(totalPages == 42)
    }

    /// postsPage() with default page and perPage should use WPRestClient's
    /// default constants.
    @Test func postsPageUsesDefaultPageAndPerPageParameters() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)

        _ = try await client.postsPage()

        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("page=1"))
        #expect(url.contains("per_page=\(WPRestClient.defaultPageSize)"))
    }

    // MARK: - posts() default parameters

    /// posts() called with no arguments should use default page (1) and
    /// defaultPageSize, and NOT include a category filter.
    @Test func postsWithoutArgumentsUsesDefaults() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)

        _ = try await client.posts()

        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("page=1"))
        #expect(url.contains("per_page=\(WPRestClient.defaultPageSize)"))
        #expect(!url.contains("categories="))
    }

    // MARK: - search() whitespace trimming and edge cases

    /// search() trims leading/trailing whitespace; a query of 2 characters
    /// after trimming should hit the network, even if the raw input is longer
    /// (e.g., "  ab  " → "ab" after trim → network call).
    @Test func searchTrimsWhitespaceBeforeMinimumCheck() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)

        _ = try await client.search(query: "   ab   ")

        let captured = await fake.capturedRequests
        #expect(captured.count == 1, "Trimmed query 'ab' should hit network")
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("search=ab"))
    }

    /// search() with only whitespace (spaces, tabs, newlines) should short-circuit
    /// to empty WITHOUT a network call (like a sub-2-char query).
    @Test func searchWithOnlyWhitespaceReturnsEmptyAndSkipsNetwork() async throws {
        let fake = FakeHTTPClient()
        let client = WPRestClient(httpClient: fake)

        let results = try await client.search(query: "     \t\n     ")

        #expect(results.isEmpty)
        let captured = await fake.capturedRequests
        #expect(captured.isEmpty, "Whitespace-only query should not hit network")
    }

    /// search() with exactly 1 character after trimming (or 0) should return
    /// empty without network call.
    @Test func searchWithSingleCharacterDoesNotHitNetwork() async throws {
        let fake = FakeHTTPClient()
        let client = WPRestClient(httpClient: fake)

        let results = try await client.search(query: "a")

        #expect(results.isEmpty)
        let captured = await fake.capturedRequests
        #expect(captured.isEmpty)
    }

    // MARK: - _embed parameter presence

    /// All post-fetch methods (posts, post(id:), post(slug:), randomPost, search)
    /// should include `_embed=wp:featuredmedia` to inline the hero image URL.
    /// Verify postsPage includes it (posts delegates to postsPage).
    @Test func postsPageIncludesEmbedParameter() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)

        _ = try await client.postsPage()

        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        // URL encoding: : → %3A
        #expect(
            url.contains("_embed=wp%3Afeaturedmedia") || url.contains("_embed=wp:featuredmedia"),
            "_embed parameter must be present for hero image inlining"
        )
    }

    /// post(slug:) should include _embed parameter to match post(id:) behavior.
    @Test func postSlugIncludesEmbedParameter() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)

        _ = try await client.post(slug: "test")

        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(
            url.contains("_embed=wp%3Afeaturedmedia") || url.contains("_embed=wp:featuredmedia"),
            "post(slug:) must include _embed parameter"
        )
    }

    // MARK: - Pagination edge cases

    /// Calling posts(page: 2) should construct the correct page parameter.
    @Test func postsConstructsCorrectPageParameter() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)

        _ = try await client.posts(page: 2)

        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("page=2"))
    }

    /// Calling posts(perPage: 50) should use the specified per_page.
    @Test func postsConstructsCorrectPerPageParameter() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)

        _ = try await client.posts(perPage: 50)

        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("per_page=50"))
    }
}

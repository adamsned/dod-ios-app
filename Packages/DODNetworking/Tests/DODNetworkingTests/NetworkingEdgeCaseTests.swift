import Foundation
import Testing

@testable import DODNetworking

// MARK: - RecipePageFetcher cache-header and encoding edge cases (DUT-388)

/// Edge-case coverage for RecipePageFetcher cache headers and LossyArray beyond existing tests.
@Suite("RecipePageFetcher cache headers (DUT-388)") struct RecipePageFetcherCacheTests {

    @Test func setsNoCacheHeader() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "recipe", html: "<html>test</html>")
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        _ = try await fetcher.html(for: url)

        let captured = await fake.capturedRequests
        let request = try #require(captured.first)
        let cacheControl = request.value(forHTTPHeaderField: "Cache-Control")
        #expect(cacheControl == "no-cache", "Cache-Control must be 'no-cache' to bypass edge cache")
    }

    @Test func setsCachePolicyReloadIgnoring() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "recipe", html: "<html>test</html>")
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        _ = try await fetcher.html(for: url)

        let captured = await fake.capturedRequests
        let request = try #require(captured.first)
        #expect(
            request.cachePolicy == .reloadIgnoringLocalCacheData,
            "Cache policy must be .reloadIgnoringLocalCacheData to bypass URLSession cache"
        )
    }

    @Test func setsAcceptHeaderTextHtml() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "recipe", html: "<html>test</html>")
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        _ = try await fetcher.html(for: url)

        let captured = await fake.capturedRequests
        let request = try #require(captured.first)
        let accept = request.value(forHTTPHeaderField: "Accept")
        #expect(accept == "text/html", "Accept header must be 'text/html'")
    }
}

// MARK: - RecipePageFetcher encoding fallback (UTF-8 → Latin-1)

@Suite("RecipePageFetcher encoding fallback") struct RecipePageFetcherEncodingTests {

    @Test func decodesUTF8Normally() async throws {
        let fake = FakeHTTPClient()
        let utf8HTML = "<html>café</html>"
        await fake.stub(urlContaining: "recipe", html: utf8HTML)
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        let html = try await fetcher.html(for: url)

        #expect(html.contains("café"), "UTF-8 should decode normally")
    }

    @Test func fallsBackToLatin1WhenUTF8Fails() async throws {
        let fake = FakeHTTPClient()
        // ISO-8859-1 (Latin-1) byte sequence for "café" (0xE9 = é)
        let latin1Bytes = Data([
            0x3C, 0x68, 0x74, 0x6D, 0x6C, 0x3E, 0x63, 0x61, 0x66, 0xE9,
            0x3C, 0x2F, 0x68, 0x74, 0x6D, 0x6C, 0x3E,
        ])
        // Stub with raw bytes to simulate a Latin-1 response
        await fake.stub(urlContaining: "recipe") { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html; charset=ISO-8859-1"]
            )
            guard let response else {
                throw WPClientError.underlying(message: "Could not synthesize response")
            }
            return (latin1Bytes, response)
        }
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        let html = try await fetcher.html(for: url)

        // Latin-1 bytes should decode to ISO-8859-1 string containing "café"
        #expect(html.contains("caf"), "Latin-1 fallback should decode the HTML")
    }
}

// MARK: - RecipePageFetcher HTTP status handling

@Suite("RecipePageFetcher HTTP status handling") struct RecipePageFetcherStatusTests {

    @Test func status404Throws() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "recipe", json: Data("{}".utf8), statusCode: 404)
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        await #expect(throws: WPClientError.httpStatus(404)) {
            _ = try await fetcher.html(for: url)
        }
    }

    @Test func status500Throws() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "recipe", json: Data("{}".utf8), statusCode: 500)
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        await #expect(throws: WPClientError.httpStatus(500)) {
            _ = try await fetcher.html(for: url)
        }
    }

    @Test func status403Throws() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "recipe", json: Data("{}".utf8), statusCode: 403)
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        await #expect(throws: WPClientError.httpStatus(403)) {
            _ = try await fetcher.html(for: url)
        }
    }

    /// Boundary case: 200 succeeds, 300 fails (3xx are redirect status, not success).
    @Test func status300IsNotSuccess() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "recipe", json: Data("{}".utf8), statusCode: 300)
        let fetcher = RecipePageFetcher(httpClient: fake)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/"))

        await #expect(throws: WPClientError.httpStatus(300)) {
            _ = try await fetcher.html(for: url)
        }
    }
}

// MARK: - LossyArray<Element> edge cases

@Suite("LossyArray decode edge cases") struct LossyArrayEdgeCaseTests {

    /// Empty array is a valid, happy-path result (no decode needed).
    @Test func emptyInputArrayReturnsEmpty() async throws {
        let empty = "[]"
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(empty.utf8))
        let client = WPRestClient(httpClient: fake)

        let items = try await client.posts()

        #expect(items.isEmpty, "Empty page should return empty array")
    }

    /// All rows malformed → LossyArray drops every row, returns empty.
    /// Missing `id` (the only truly required field) fails decode.
    private let pageWithAllBadRows = """
        [
          {
            "slug": "broken-one",
            "link": "https://www.dutchovendaddy.com/broken-one/"
          },
          {
            "slug": "broken-two",
            "link": "https://www.dutchovendaddy.com/broken-two/"
          },
          {
            "slug": "broken-three",
            "link": "https://www.dutchovendaddy.com/broken-three/"
          }
        ]
        """

    @Test func allRowsMalformedReturnsEmpty() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(pageWithAllBadRows.utf8))
        let client = WPRestClient(httpClient: fake)

        let items = try await client.posts()

        #expect(
            items.isEmpty,
            "All rows missing id should return empty, not throw"
        )
    }

    /// Single good row is a valid LossyArray result.
    private let pageWithSingleGoodRow = """
        [
          {
            "id": 1,
            "slug": "lone-recipe",
            "link": "https://www.dutchovendaddy.com/lone-recipe/",
            "title": { "rendered": "Lone Recipe" },
            "excerpt": { "rendered": "<p>Alone.</p>" }
          }
        ]
        """

    @Test func singleGoodRowReturnsOne() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(pageWithSingleGoodRow.utf8))
        let client = WPRestClient(httpClient: fake)

        let items = try await client.posts()

        #expect(items.count == 1, "Single good row should return array of one")
        let item = try #require(items.first)
        #expect(item.id == 1)
        #expect(item.title == "Lone Recipe")
    }

    /// LossyArray applies to search results too.
    /// Missing `id` field fails decode for all rows.
    private let searchResultsAllBad = """
        [
          {
            "slug": "search-fail-one",
            "link": "https://www.dutchovendaddy.com/search-fail-one/"
          },
          {
            "slug": "search-fail-two",
            "link": "https://www.dutchovendaddy.com/search-fail-two/"
          }
        ]
        """

    @Test func searchWithAllBadRowsReturnsEmpty() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(searchResultsAllBad.utf8))
        let client = WPRestClient(httpClient: fake)

        let results = try await client.search(query: "somethingbroken")

        #expect(
            results.isEmpty,
            "Search results where all rows fail decode (missing id) should return empty, not throw"
        )
    }

    /// LossyArray applies to categories endpoint too.
    private let categoriesAllMalformed = """
        [
          { "id": 1, "name": "Broken One" },
          { "id": 2, "name": "Broken Two" }
        ]
        """

    @Test func categoriesWithAllMalformedRowsReturnsEmpty() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "categories", json: Data(categoriesAllMalformed.utf8))
        let client = WPRestClient(httpClient: fake)

        let categories = try await client.categories()

        #expect(
            categories.isEmpty,
            "Categories where all rows fail (missing required slug) should return empty"
        )
    }
}

// MARK: - WPRestClient.parseTotalPages edge cases

@Suite("WPRestClient.parseTotalPages edge cases") struct WPRestClientParseTotalPagesTests {

    @Test func missingHeaderDefaultsToOne() {
        let response = HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )
        let pages = WPRestClient.parseTotalPages(response ?? HTTPURLResponse())
        #expect(pages == 1, "Missing X-WP-TotalPages header should default to 1")
    }

    @Test func zeroValueClampsToOne() {
        let response = HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["X-WP-TotalPages": "0"]
        )
        let pages = WPRestClient.parseTotalPages(response ?? HTTPURLResponse())
        #expect(
            pages == 1,
            "Zero in X-WP-TotalPages (DUT-397) should clamp to 1 (at least one page exists)"
        )
    }

    @Test func negativeValueClampsToOne() {
        let response = HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["X-WP-TotalPages": "-5"]
        )
        let pages = WPRestClient.parseTotalPages(response ?? HTTPURLResponse())
        #expect(pages == 1, "Negative X-WP-TotalPages should clamp to 1")
    }

    @Test func unparseableValueDefaultsToOne() {
        let response = HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["X-WP-TotalPages": "notanumber"]
        )
        let pages = WPRestClient.parseTotalPages(response ?? HTTPURLResponse())
        #expect(pages == 1, "Unparseable X-WP-TotalPages should default to 1")
    }

    @Test func validPositiveValuePreserved() {
        let response = HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["X-WP-TotalPages": "42"]
        )
        let pages = WPRestClient.parseTotalPages(response ?? HTTPURLResponse())
        #expect(pages == 42, "Valid positive X-WP-TotalPages should be preserved")
    }
}

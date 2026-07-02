import Foundation
import Testing

@testable import DODNetworking

@Suite("WPRestClient.posts") struct WPRestClientPostsTests {

    private let fixture = """
        [
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
        ]
        """

    @Test func decodesAndMapsToRecipeListItem() async throws {
        let client = await makeClient(stubURL: "posts", json: fixture)
        let items = try await client.posts()
        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.id == 21238)
        #expect(item.title == "Garlic Butter Skillet Corn")
        #expect(item.excerpt == "Easy 15-minute side dish.")
        // T-530 / CL-53 / REG-17: the WP `categories` array on the wire
        // must round-trip into `RecipeListItem.categoryIDs` so the
        // downstream cache pass + Search-tab category chip can filter
        // fresh REST hits.
        #expect(item.categoryIDs == [1590, 334])
    }

    @Test func sendsCategoryParameterWhenScoped() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(fixture.utf8))
        let client = WPRestClient(httpClient: fake)
        _ = try await client.posts(categoryID: 336)
        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("categories=336"))
    }

    @Test func includesPagingParameters() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(fixture.utf8))
        let client = WPRestClient(httpClient: fake)
        _ = try await client.posts(page: 3, perPage: 20)
        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("page=3"))
        #expect(url.contains("per_page=20"))
    }

    @Test func httpErrorStatusThrows() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8), statusCode: 500)
        let client = WPRestClient(httpClient: fake)
        await #expect(throws: WPClientError.httpStatus(500)) {
            _ = try await client.posts()
        }
    }

    /// REG-20 / CL-101 (T-632): the single-post-by-id endpoint backing the
    /// notification deep-link fetch-on-cache-miss path. A notification
    /// targets a brand-new (uncached) post, so the tap handler fetches it
    /// here to obtain its `canonicalURL` before routing to recipe-detail.
    /// The response is a single object (not an array like `posts()`), and
    /// the request must carry `_embed=wp:featuredmedia` and hit
    /// `posts/<id>`.
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

    @Test func fetchesSinglePostByID() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts/21238", json: Data(singlePostFixture.utf8))
        let client = WPRestClient(httpClient: fake)
        let item = try await client.post(id: 21238)
        #expect(item.id == 21238)
        #expect(item.title == "Garlic Butter Skillet Corn")
        // The canonicalURL is the load-bearing field for the deep-link
        // path — the recipe-detail screen fetches + classifies this URL.
        #expect(item.canonicalURL?.absoluteString == "https://www.dutchovendaddy.com/garlic-butter-skillet-corn/")
        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("posts/21238"))
        #expect(url.contains("_embed=wp%3Afeaturedmedia") || url.contains("_embed=wp:featuredmedia"))
    }

    @Test func singlePostHTTPErrorStatusThrows() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts/999", json: Data("{}".utf8), statusCode: 404)
        let client = WPRestClient(httpClient: fake)
        await #expect(throws: WPClientError.httpStatus(404)) {
            _ = try await client.post(id: 999)
        }
    }

    @Test func fetchesPostBySlug() async throws {
        // DOD-ART-2: tapping an article's recipe link resolves the URL slug to
        // a post via `?slug=`.
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(fixture.utf8))
        let client = WPRestClient(httpClient: fake)
        let item = try await client.post(slug: "garlic-butter-skillet-corn")
        #expect(item?.id == 21238)
        #expect(item?.title == "Garlic Butter Skillet Corn")
        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("slug=garlic-butter-skillet-corn"))
    }

    @Test func postBySlugReturnsNilWhenNoMatch() async throws {
        // A link to a WP *page* (not a recipe post) → empty array → nil, so
        // RootView falls back to opening it in the browser.
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)
        let item = try await client.post(slug: "about-me")
        #expect(item == nil)
    }
}

@Suite("WPRestClient.search") struct WPRestClientSearchTests {

    @Test func shortQueriesShortCircuitToEmpty() async throws {
        let fake = FakeHTTPClient()
        let client = WPRestClient(httpClient: fake)
        let results = try await client.search(query: "a")
        #expect(results.isEmpty)
        let captured = await fake.capturedRequests
        #expect(captured.isEmpty)
    }

    @Test func twoCharQueryHitsTheNetwork() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)
        _ = try await client.search(query: "ab")
        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("search=ab"))
    }

    /// CL-120 / T-642 / REG-29: the SEARCH path widens `per_page` to 100
    /// so the post-fetch title-precision filter has a candidate pool
    /// big enough to lift WP-relevance-buried title matches above the
    /// truncation cutoff. Locks the search-specific page-size bump
    /// separately from the list endpoints' `defaultPageSize` (still 20).
    @Test func searchUsesWidePageSizeForTitlePrecision() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)
        _ = try await client.search(query: "nachos")
        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("per_page=100"), "Search must widen per_page to 100 (CL-120 / T-642)")
        #expect(url.contains("search=nachos"))
    }

    /// DUT-438: `&` and `=` are raw query delimiters that `.urlQueryAllowed`
    /// permits — unencoded, "mac & cheese" split the query string and the
    /// server received `search = "mac "`. They must round-trip as %26 / %3D.
    @Test func ampersandAndEqualsInQueryAreProperlyEncoded() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let client = WPRestClient(httpClient: fake)
        _ = try await client.search(query: "mac & a=b cheese")
        let captured = await fake.capturedRequests
        let url = try #require(captured.first?.url?.absoluteString)
        #expect(url.contains("search=mac%20%26%20a%3Db%20cheese"))
        // The raw delimiters must not appear inside the value.
        #expect(!url.contains("search=mac%20&"))
    }
}

@Suite("WPRestClient.categories") struct WPRestClientCategoriesTests {

    private let fixture = """
        [
          { "id": 336, "name": "Desserts", "slug": "desserts", "count": 42 },
          { "id": 334, "name": "Sides",    "slug": "sides",    "count": 27 },
          { "id": 999, "name": "Empty",    "slug": "empty",    "count": 0 }
        ]
        """

    @Test func sortsAlphabeticallyAndDropsEmpties() async throws {
        let client = await makeClient(stubURL: "categories", json: fixture)
        let categories = try await client.categories()
        let names = categories.map { $0.name }
        #expect(names == ["Desserts", "Sides"])
    }
}

@Suite("WPRestClient.media") struct WPRestClientMediaTests {

    private let fixture = """
        {
          "source_url": "https://example.com/source.jpg",
          "media_details": {
            "sizes": {
              "medium":       { "source_url": "https://example.com/m.jpg",  "width":  300, "height": 200 },
              "medium_large": { "source_url": "https://example.com/ml.jpg", "width":  768, "height": 512 },
              "large":        { "source_url": "https://example.com/l.jpg",  "width": 1024, "height": 682 },
              "huge":         { "source_url": "https://example.com/h.jpg",  "width": 4096, "height": 2730 }
            }
          }
        }
        """

    @Test func resolvesListAndHeroSizes() async throws {
        let client = await makeClient(stubURL: "media", json: fixture)
        let sizes = try await client.media(id: 23019)
        #expect(sizes.listImageURL?.absoluteString == "https://example.com/ml.jpg")
        // largest ≤ 2048 — `large` wins because `huge` is filtered out
        #expect(sizes.heroImageURL?.absoluteString == "https://example.com/l.jpg")
    }

    @Test func fallsBackToSourceURLWhenNoSizes() async throws {
        let bare = """
            { "source_url": "https://example.com/only.jpg" }
            """
        let client = await makeClient(stubURL: "media", json: bare)
        let sizes = try await client.media(id: 1)
        #expect(sizes.listImageURL?.absoluteString == "https://example.com/only.jpg")
        #expect(sizes.heroImageURL?.absoluteString == "https://example.com/only.jpg")
    }
}

// MARK: - helpers

private func makeClient(stubURL: String, json: String) async -> WPRestClient {
    let fake = FakeHTTPClient()
    await fake.stub(urlContaining: stubURL, json: Data(json.utf8))
    return WPRestClient(httpClient: fake)
}

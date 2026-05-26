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

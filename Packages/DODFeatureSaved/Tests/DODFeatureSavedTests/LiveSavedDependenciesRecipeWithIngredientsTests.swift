import DODDomain
import DODNetworking
import DODPersistence
import Foundation
import Testing

@testable import DODFeatureSaved

@Suite("LiveSavedDependencies.recipeWithIngredients (DUT-487)")
@MainActor
struct RecipeWithIngredientsTests {

    // MARK: - Test 1: Recipe with non-empty ingredients returns unchanged
    @Test func nonEmptyIngredientsReturnsUnchangedWithoutNetworkCalls() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let fakeHTTPClient = FakeHTTPClient()

        let deps = LiveSavedDependencies(
            store: store,
            imageLoader: ImageLoader(httpClient: fakeHTTPClient),
            pageFetcher: RecipePageFetcher(httpClient: fakeHTTPClient),
            remoteChangeStream: nil,
            monitor: .shared,
            publishWidget: nil
        )

        let originalRecipe = Recipe(
            id: 1,
            slug: "test-recipe",
            title: "Test Recipe",
            excerpt: "A test recipe.",
            canonicalURL: try #require(URL(string: "https://www.dutchovendaddy.com/test-recipe/")),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [RecipeIngredient(text: "2 cups flour")]
        )

        let result = await deps.recipeWithIngredients(originalRecipe)

        #expect(result == originalRecipe)
        #expect(fakeHTTPClient.capturedRequests.isEmpty)
    }

    // MARK: - Test 2: Empty ingredients with store cache hit returns cached recipe
    @Test func emptyIngredientsWithCachedVersionReturnsCached() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)

        let cachedRecipe = Recipe(
            id: 42,
            slug: "cached-recipe",
            title: "Cached Recipe",
            excerpt: "Already hydrated.",
            canonicalURL: try #require(URL(string: "https://www.dutchovendaddy.com/cached-recipe/")),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [RecipeIngredient(text: "3 eggs")]
        )
        try await store.mergeDetail(cachedRecipe)

        let fakeHTTPClient = FakeHTTPClient()
        let deps = LiveSavedDependencies(
            store: store,
            imageLoader: ImageLoader(httpClient: fakeHTTPClient),
            pageFetcher: nil,
            remoteChangeStream: nil,
            monitor: .shared,
            publishWidget: nil
        )

        let emptyRecipe = Recipe(
            id: 42,
            slug: "cached-recipe",
            title: "Cached Recipe",
            excerpt: "Already hydrated.",
            canonicalURL: try #require(URL(string: "https://www.dutchovendaddy.com/cached-recipe/")),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: []
        )

        let result = await deps.recipeWithIngredients(emptyRecipe)

        #expect(result.ingredients.count == 1)
        #expect(result.ingredients[0].text == "3 eggs")
        #expect(result == cachedRecipe)
    }

    // MARK: - Test 3: No cache and nil pageFetcher returns original unchanged
    @Test func noFetcherWiredReturnsOriginalUnchanged() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let fakeHTTPClient = FakeHTTPClient()

        let deps = LiveSavedDependencies(
            store: store,
            imageLoader: ImageLoader(httpClient: fakeHTTPClient),
            pageFetcher: nil,
            remoteChangeStream: nil,
            monitor: .shared,
            publishWidget: nil
        )

        let emptyRecipe = Recipe(
            id: 99,
            slug: "no-fetcher-recipe",
            title: "No Fetcher Recipe",
            excerpt: "Fetch will be skipped.",
            canonicalURL: try #require(URL(string: "https://www.dutchovendaddy.com/no-fetcher-recipe/")),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: []
        )

        let result = await deps.recipeWithIngredients(emptyRecipe)

        #expect(result == emptyRecipe)
        #expect(result.ingredients.isEmpty)
    }

    // MARK: - Test 4: Successful fetch and parse hydrates and persists
    @Test func successfulFetchAndParsePersistsToStore() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let fakeHTTPClient = FakeHTTPClient()
        fakeHTTPClient.responseHTML = jsonLDFixture()

        let deps = LiveSavedDependencies(
            store: store,
            imageLoader: ImageLoader(httpClient: fakeHTTPClient),
            pageFetcher: RecipePageFetcher(httpClient: fakeHTTPClient),
            remoteChangeStream: nil,
            monitor: .shared,
            publishWidget: nil
        )

        let canonicalURL = try #require(
            URL(string: "https://www.dutchovendaddy.com/hydrated-recipe/")
        )
        let emptyRecipe = Recipe(
            id: 123,
            slug: "hydrated-recipe",
            title: "Hydrated Recipe",
            excerpt: "Will be hydrated.",
            canonicalURL: canonicalURL,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: []
        )

        let result = await deps.recipeWithIngredients(emptyRecipe)

        #expect(result.ingredients.count == 3)
        let ingredientTexts = result.ingredients.map { $0.text }
        #expect(ingredientTexts == ["2 cups flour", "1 cup sugar", "3 eggs"])
        #expect(result.servings == 4)

        let stored = try await store.recipe(id: 123)
        #expect(stored != nil)
        if let storedRecipe = stored {
            let texts = storedRecipe.ingredients.map { $0.text }
            #expect(texts == ["2 cups flour", "1 cup sugar", "3 eggs"])
        }
    }

    private func jsonLDFixture() -> String {
        """
        <html><head><script type="application/ld+json">{
        "@context":"https://schema.org/","@type":"Recipe",
        "name":"Hydrated Recipe","recipeYield":"4",
        "recipeIngredient":["2 cups flour","1 cup sugar","3 eggs"],
        "recipeInstructions":[
        {"@type":"HowToStep","text":"Mix dry ingredients."},
        {"@type":"HowToStep","text":"Add eggs and mix."}]}</script>
        </head></html>
        """
    }

    // MARK: - Test 5: Fetch failure returns original unchanged
    @Test func fetchFailureReturnsOriginalUnchanged() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let throwingHTTPClient = ThrowingHTTPClient()

        let deps = LiveSavedDependencies(
            store: store,
            imageLoader: ImageLoader(httpClient: throwingHTTPClient),
            pageFetcher: RecipePageFetcher(httpClient: throwingHTTPClient),
            remoteChangeStream: nil,
            monitor: .shared,
            publishWidget: nil
        )

        let emptyRecipe = Recipe(
            id: 456,
            slug: "fetch-fail-recipe",
            title: "Fetch Fail Recipe",
            excerpt: "Fetch will throw.",
            canonicalURL: try #require(URL(string: "https://www.dutchovendaddy.com/fetch-fail-recipe/")),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: []
        )

        let result = await deps.recipeWithIngredients(emptyRecipe)

        #expect(result == emptyRecipe)
        #expect(result.ingredients.isEmpty)
    }
}

// MARK: - Test Helpers

private final class FakeHTTPClient: HTTPClient, @unchecked Sendable {
    var responseHTML: String = ""
    var capturedRequests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequests.append(request)
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        guard let httpResponse = response else {
            throw URLError(.badServerResponse)
        }
        guard let htmlData = responseHTML.data(using: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        return (htmlData, httpResponse)
    }
}

private struct ThrowingHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw URLError(.badServerResponse)
    }
}

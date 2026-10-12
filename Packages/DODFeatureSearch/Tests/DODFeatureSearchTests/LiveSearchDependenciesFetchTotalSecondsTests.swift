import DODDomain
import DODNetworking
import DODPersistence
import Foundation
import Testing

@testable import DODFeatureSearch

/// US-12 / AC-12.3 amendment / CL-106 (T-637): `LiveSearchDependencies
/// .fetchTotalSeconds(forRecipeIDs:)` gap-coverage tests. The function
/// hydrates cook-time metadata by fetching each recipe's HTML, parsing
/// JSON-LD, and caching the result. Per-id failures are silently swallowed
/// (logged but not propagated), and ids already in the store's cache are
/// skipped to avoid re-fetching.
///
/// `LiveSearchDependencies` was never constructed in any test in this
/// package before these tests. The function is non-throwing and handles
/// its own error recovery (try? on store writes, catch/log on per-id
/// failures), so the key coverage is: (1) cache hits skip network entirely,
/// (2) failures per-id don't propagate, (3) empty input short-circuits early.
@Suite("LiveSearchDependencies.fetchTotalSeconds gap coverage (US-12)")
struct FetchTotalSecondsTests {

    // MARK: - All ids cached: zero network calls, return cache values

    @Test func allIDsAlreadyCachedSkipNetworkAndReturnCachedValues() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let fake = FakeHTTPClient()
        let deps = LiveSearchDependencies(
            client: WPRestClient(httpClient: fake),
            store: store,
            monitor: NetworkMonitor.shared,
            fetcher: RecipePageFetcher(httpClient: fake)
        )

        // Seed the store with cached total seconds for id 100 and 200.
        let now = Date.now
        let cachedRecipes = [
            Recipe.stub(id: 100, totalTime: .seconds(30 * 60), publishedAt: now),
            Recipe.stub(id: 200, totalTime: .seconds(45 * 60), publishedAt: now),
        ]
        for recipe in cachedRecipes {
            try await store.mergeDetail(recipe)
        }

        // Fetch — should not trigger any network calls since ids are cached.
        let result = await deps.fetchTotalSeconds(forRecipeIDs: [100, 200])

        // Verify results match the cache.
        #expect(result[100] == 30 * 60)
        #expect(result[200] == 45 * 60)
        // Verify zero network calls were made (access via await on actor).
        let requests = await fake.capturedRequests
        #expect(requests.isEmpty)
    }

    // MARK: - Empty input: early return with zero network calls

    @Test func emptyIDsReturnEmptyDictWithoutNetworkCalls() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let fake = FakeHTTPClient()
        let deps = LiveSearchDependencies(
            client: WPRestClient(httpClient: fake),
            store: store,
            monitor: NetworkMonitor.shared,
            fetcher: RecipePageFetcher(httpClient: fake)
        )

        let result = await deps.fetchTotalSeconds(forRecipeIDs: [])

        #expect(result.isEmpty)
        let requests = await fake.capturedRequests
        #expect(requests.isEmpty)
    }

    // MARK: - Pending id with successful fetch+parse: added to result

    @Test func pendingIDWithSuccessfulFetchAndParseAddsToResult() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let fake = FakeHTTPClient()
        let deps = LiveSearchDependencies(
            client: WPRestClient(httpClient: fake),
            store: store,
            monitor: NetworkMonitor.shared,
            fetcher: RecipePageFetcher(httpClient: fake)
        )

        // Stub the WP post endpoint to return a recipe with a canonical URL.
        // post(id:) expects a SINGLE post object, not an array.
        let postJSON = """
            {
              "id": 300,
              "slug": "test-recipe",
              "link": "https://www.dutchovendaddy.com/test-recipe/",
              "title": { "rendered": "Test Recipe" },
              "excerpt": { "rendered": "<p>A test.</p>" },
              "date": "2026-07-01T10:00:00",
              "categories": []
            }
            """
        await fake.stub(urlContaining: "posts/300", json: Data(postJSON.utf8))

        // Stub the HTML fetch with a JSON-LD script containing totalTime.
        let htmlWithJSONLD = #"""
            <script type="application/ld+json">
            {
              "@context": "https://schema.org/",
              "@type": "Recipe",
              "name": "Test Recipe",
              "prepTime": "PT5M",
              "cookTime": "PT20M",
              "totalTime": "PT25M",
              "recipeYield": "2",
              "recipeIngredient": ["1 cup flour"],
              "recipeInstructions": [
                { "@type": "HowToStep", "text": "Mix." }
              ]
            }
            </script>
            """#
        await fake.stub(urlContaining: "dutchovendaddy.com", html: htmlWithJSONLD)

        // Fetch the pending id — should trigger network fetch and parse.
        let result = await deps.fetchTotalSeconds(forRecipeIDs: [300])

        // Verify result contains the parsed totalTime (25 minutes = 1500 seconds).
        #expect(result[300] == 25 * 60)
    }

    // MARK: - Pending id with HTML fetch failure: silently dropped

    @Test func pendingIDWithHTMLFetchFailureIsSilentlyDropped() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let fake = FakeHTTPClient()
        let deps = LiveSearchDependencies(
            client: WPRestClient(httpClient: fake),
            store: store,
            monitor: NetworkMonitor.shared,
            fetcher: RecipePageFetcher(httpClient: fake)
        )

        // Stub the WP post endpoint. post(id:) expects a SINGLE post object.
        let postJSON = """
            {
              "id": 400,
              "slug": "failing-recipe",
              "link": "https://www.dutchovendaddy.com/failing-recipe/",
              "title": { "rendered": "Failing Recipe" },
              "excerpt": { "rendered": "<p>Fails.</p>" },
              "date": "2026-07-01T10:00:00",
              "categories": []
            }
            """
        await fake.stub(urlContaining: "posts/400", json: Data(postJSON.utf8))

        // Stub the HTML fetch to fail for the canonical URL.
        await fake.stub(
            urlContaining: "dutchovendaddy.com",
            with: { _ in
                throw URLError(.notConnectedToInternet)
            }
        )

        // Fetch — HTML will fail, error should be swallowed.
        let result = await deps.fetchTotalSeconds(forRecipeIDs: [400])

        // Verify id 400 is NOT in the result (error-swallowed, silently dropped).
        #expect(result[400] == nil)
        #expect(!result.keys.contains(400))
        // Function did not throw; result is a clean dict without the failed id.
        #expect(result.isEmpty)
    }

    // MARK: - Mixed: one cached, one pending — cache hit skipped, pending fetched

    @Test func mixedCachedAndPendingIDsHandlesEachAppropriatly() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let fake = FakeHTTPClient()
        let deps = LiveSearchDependencies(
            client: WPRestClient(httpClient: fake),
            store: store,
            monitor: NetworkMonitor.shared,
            fetcher: RecipePageFetcher(httpClient: fake)
        )

        // Seed cache with id 500.
        let now = Date.now
        let cachedRecipe = Recipe.stub(id: 500, totalTime: .seconds(20 * 60), publishedAt: now)
        try await store.mergeDetail(cachedRecipe)

        // Stub endpoints for the pending id 600.
        let postJSON = """
            {
              "id": 600,
              "slug": "pending-recipe",
              "link": "https://www.dutchovendaddy.com/pending-recipe/",
              "title": { "rendered": "Pending Recipe" },
              "excerpt": { "rendered": "<p>Pending.</p>" },
              "date": "2026-07-01T10:00:00",
              "categories": []
            }
            """
        await fake.stub(urlContaining: "posts/600", json: Data(postJSON.utf8))

        let htmlWithJSONLD = #"""
            <script type="application/ld+json">
            {
              "@context": "https://schema.org/",
              "@type": "Recipe",
              "name": "Pending Recipe",
              "totalTime": "PT35M",
              "recipeYield": "1",
              "recipeIngredient": ["sugar"],
              "recipeInstructions": [
                { "@type": "HowToStep", "text": "Enjoy." }
              ]
            }
            </script>
            """#
        await fake.stub(urlContaining: "dutchovendaddy.com", html: htmlWithJSONLD)

        // Fetch both ids: 500 (cached) and 600 (pending).
        let result = await deps.fetchTotalSeconds(forRecipeIDs: [500, 600])

        // Cached id passes through unchanged.
        #expect(result[500] == 20 * 60)
        // Pending id is fetched and parsed.
        #expect(result[600] == 35 * 60)
    }
}

// MARK: - Test Fixtures

/// Minimal `Recipe.stub(id:totalTime:publishedAt:)` helper for seeding test store.
/// Uses defaults for all other fields (name, ingredients, etc.) since only
/// the `id` and `totalTime` matter for `fetchTotalSeconds` cache behavior.
extension Recipe {
    fileprivate static func stub(
        id: Int,
        totalTime: Duration,
        publishedAt: Date
    ) -> Recipe {
        Recipe(
            id: id,
            slug: "stub-recipe-\(id)",
            title: "Stub Recipe \(id)",
            excerpt: "Test fixture",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/stub-\(id)/")
                ?? URL(filePath: "/"),
            publishedAt: publishedAt,
            totalTime: totalTime
        )
    }
}

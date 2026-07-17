import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("LiveRecipeDetailDependencies.downloadForOffline image caching (DUT-418)")
struct LiveDependenciesDownloadImageCacheTests {

    // MARK: - Setup Helpers

    /// Create an in-memory store + dependencies ready for testing downloadForOffline.
    /// The imageLoader is wired to the provided fakeHTTPClient.
    private func makeDeps(
        fakeHTTPClient: FakeHTTPClient
    ) throws -> (store: RecipeStore, deps: LiveRecipeDetailDependencies) {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let deps = LiveRecipeDetailDependencies(
            client: WPRestClient(),
            fetcher: RecipePageFetcher(),
            store: store,
            monitor: NetworkMonitor.shared,
            commentsClient: WPCommentsClient(),
            ratingsClient: WPRMRatingsClient(httpClient: FakeHTTPClient()),
            guestIdentity: NoopGuestIdentityStore(),
            imageLoader: ImageLoader(httpClient: fakeHTTPClient),
            savedWidgetPublisher: nil
        )
        return (store, deps)
    }

    /// Create a test recipe with optional large + small hero URLs.
    private func makeRecipe(
        id: Int,
        heroImage: URL? = nil,
        heroImageLargeURL: URL? = nil
    ) -> Recipe {
        Recipe(
            id: id,
            slug: "test-slug",
            title: "Test Recipe",
            excerpt: "Test excerpt",
            canonicalURL: URL(string: "https://example.com/recipe/test")
                ?? URL(filePath: "/"),
            heroImage: heroImage,
            heroImageLargeURL: heroImageLargeURL,
            publishedAt: Date()
        )
    }

    /// Insert a recipe into the store so that downloadForOffline can find it.
    /// (markDownloaded needs the recipe to exist in the store first.)
    private func insertRecipeIntoStore(
        _ store: RecipeStore,
        recipe: Recipe
    ) async throws {
        let listItem = RecipeListItem(
            id: recipe.id,
            title: recipe.title,
            excerpt: recipe.excerpt,
            heroImage: recipe.heroImage,
            publishedAt: recipe.publishedAt,
            totalTimeDisplay: nil,
            canonicalURL: recipe.canonicalURL,
            categoryIDs: nil
        )
        try await store.cache(listItem: listItem)
    }

    /// Helper to create an HTTPURLResponse, using a default fallback if construction fails.
    private func makeHTTPResponse(
        url: URL,
        statusCode: Int = 200
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        ) ?? HTTPURLResponse()
    }

    // MARK: - Test Cases

    /// Case 1: Fresh download with distinct large + small URLs (both succeed).
    /// Verifies: large URL cached with large bytes, small URL cached with small bytes,
    /// both are distinct, and outcome is .firstTime.
    @Test func freshDownloadDistinctLargeAndSmallUrlsBothSucceed() async throws {
        let fakeClient = FakeHTTPClient()
        let (store, deps) = try makeDeps(fakeHTTPClient: fakeClient)

        let largeURL =
            URL(string: "https://example.com/hero-large.jpg")
            ?? URL(filePath: "/")
        let smallURL =
            URL(string: "https://example.com/hero-small.jpg")
            ?? URL(filePath: "/")
        let largeBytes = Data([0x01, 0x02, 0x03])
        let smallBytes = Data([0x04, 0x05, 0x06])

        let recipe = makeRecipe(id: 100, heroImage: smallURL, heroImageLargeURL: largeURL)
        try await insertRecipeIntoStore(store, recipe: recipe)

        // Stub the large URL to return large bytes.
        await fakeClient.stub(urlContaining: "hero-large") { request in
            (largeBytes, self.makeHTTPResponse(url: request.url ?? largeURL))
        }

        // Stub the small URL to return small bytes.
        await fakeClient.stub(urlContaining: "hero-small") { request in
            (smallBytes, self.makeHTTPResponse(url: request.url ?? smallURL))
        }

        let outcome = try await deps.downloadForOffline(recipe: recipe)

        #expect(outcome == .firstTime)
        let cachedLargeBytes = try await store.image(url: largeURL)
        let cachedSmallBytes = try await store.image(url: smallURL)
        #expect(cachedLargeBytes == largeBytes, "Large URL should cache large bytes")
        #expect(cachedSmallBytes == smallBytes, "Small URL should cache small bytes")
    }

    /// Case 2: Fresh download where large == small (only heroImage, no heroImageLargeURL).
    /// Verifies: exactly ONE fetch happens, ONE URL cached with correct bytes,
    /// outcome is .firstTime.
    @Test func freshDownloadLargeEqualsSmallOnlyOneUrlFetched() async throws {
        let fakeClient = FakeHTTPClient()
        let (store, deps) = try makeDeps(fakeHTTPClient: fakeClient)

        let imageURL =
            URL(string: "https://example.com/hero.jpg")
            ?? URL(filePath: "/")
        let imageBytes = Data([0xAA, 0xBB, 0xCC])

        let recipe = makeRecipe(id: 101, heroImage: imageURL, heroImageLargeURL: nil)
        try await insertRecipeIntoStore(store, recipe: recipe)

        // Stub the single URL.
        await fakeClient.stub(urlContaining: "hero.jpg") { request in
            (imageBytes, self.makeHTTPResponse(url: request.url ?? imageURL))
        }

        let outcome = try await deps.downloadForOffline(recipe: recipe)

        #expect(outcome == .firstTime)
        // Verify exactly one fetch happened (one captured request).
        let capturedCount = await fakeClient.capturedRequests.count
        #expect(capturedCount == 1, "Should fetch exactly once")
        // Verify the one URL is cached with correct bytes.
        let cachedBytes = try await store.image(url: imageURL)
        #expect(cachedBytes == imageBytes, "Single URL should cache with correct bytes")
    }

    /// Case 3: Fresh download where small-URL fetch fails but large succeeds.
    /// Verifies: small URL still ends up cached, but with LARGE bytes (fallback behavior),
    /// outcome is .firstTime, and large URL is also cached.
    /// This pins the DUT-418 widget-thumbnail quirk: when the small fetch fails,
    /// reuse large bytes so the widget doesn't show a placeholder forever.
    @Test func freshDownloadSmallUrlFetchFailsFallsBackToLargeBytes() async throws {
        let fakeClient = FakeHTTPClient()
        let (store, deps) = try makeDeps(fakeHTTPClient: fakeClient)

        let largeURL =
            URL(string: "https://example.com/hero-large.jpg")
            ?? URL(filePath: "/")
        let smallURL =
            URL(string: "https://example.com/hero-small.jpg")
            ?? URL(filePath: "/")
        let largeBytes = Data([0xCC, 0xDD, 0xEE])

        let recipe = makeRecipe(id: 102, heroImage: smallURL, heroImageLargeURL: largeURL)
        try await insertRecipeIntoStore(store, recipe: recipe)

        // Stub the large URL to succeed.
        await fakeClient.stub(urlContaining: "hero-large") { request in
            (largeBytes, self.makeHTTPResponse(url: request.url ?? largeURL))
        }

        // Stub the small URL to fail.
        await fakeClient.stub(urlContaining: "hero-small") { _ in
            throw URLError(.notConnectedToInternet)
        }

        let outcome = try await deps.downloadForOffline(recipe: recipe)

        #expect(outcome == .firstTime)
        // Large URL should be cached with large bytes.
        let cachedLargeBytes = try await store.image(url: largeURL)
        #expect(cachedLargeBytes == largeBytes, "Large URL should be cached")
        // Small URL should ALSO be cached, but with the LARGE bytes (fallback).
        let cachedSmallBytes = try await store.image(url: smallURL)
        #expect(
            cachedSmallBytes == largeBytes,
            "Small URL should be cached with large bytes as fallback"
        )
    }

    /// Case 4: Fresh download where PRIMARY (large) fetch fails entirely.
    /// Verifies: downloadForOffline does NOT throw, still returns .firstTime
    /// (best-effort image, metadata pin unaffected), and store.isDownloaded(id)
    /// is true (metadata was already pinned before image fetch).
    @Test func freshDownloadPrimaryFetchFailsMetadataPinStillLands() async throws {
        let fakeClient = FakeHTTPClient()
        let (store, deps) = try makeDeps(fakeHTTPClient: fakeClient)

        let largeURL =
            URL(string: "https://example.com/hero-large.jpg")
            ?? URL(filePath: "/")
        let smallURL =
            URL(string: "https://example.com/hero-small.jpg")
            ?? URL(filePath: "/")

        let recipe = makeRecipe(id: 103, heroImage: smallURL, heroImageLargeURL: largeURL)
        try await insertRecipeIntoStore(store, recipe: recipe)

        // Stub the large URL to fail.
        await fakeClient.stub(urlContaining: "hero-large") { _ in
            throw URLError(.badServerResponse)
        }

        // Stub the small URL (even though it won't be tried since large fails).
        await fakeClient.stub(urlContaining: "hero-small") { request in
            (Data([0xFF]), self.makeHTTPResponse(url: request.url ?? smallURL))
        }

        // downloadForOffline should not throw even though the image fetch fails.
        let outcome = try await deps.downloadForOffline(recipe: recipe)

        #expect(outcome == .firstTime, "Should return .firstTime even with image fetch failure")
        // The metadata pin should still have landed.
        let isDownloaded = try await store.isDownloaded(id: recipe.id)
        #expect(isDownloaded, "Recipe should be marked downloaded despite image fetch failure")
    }

    /// Case 5: Re-download of an already-downloaded recipe.
    /// Verifies: second call returns .alreadyDownloaded, no additional image
    /// fetches happen (capturedRequests count stays the same), and no exception
    /// is thrown.
    @Test func redownloadAlreadyDownloadedRecipeSkipsImageRefetch() async throws {
        let fakeClient = FakeHTTPClient()
        let (store, deps) = try makeDeps(fakeHTTPClient: fakeClient)

        let largeURL =
            URL(string: "https://example.com/hero-large.jpg")
            ?? URL(filePath: "/")
        let smallURL =
            URL(string: "https://example.com/hero-small.jpg")
            ?? URL(filePath: "/")
        let largeBytes = Data([0x11, 0x22, 0x33])
        let smallBytes = Data([0x44, 0x55, 0x66])

        let recipe = makeRecipe(id: 104, heroImage: smallURL, heroImageLargeURL: largeURL)
        try await insertRecipeIntoStore(store, recipe: recipe)

        // Stub both URLs.
        await fakeClient.stub(urlContaining: "hero-large") { request in
            (largeBytes, self.makeHTTPResponse(url: request.url ?? largeURL))
        }

        await fakeClient.stub(urlContaining: "hero-small") { request in
            (smallBytes, self.makeHTTPResponse(url: request.url ?? smallURL))
        }

        // First download should succeed and fetch both URLs.
        let firstOutcome = try await deps.downloadForOffline(recipe: recipe)
        #expect(firstOutcome == .firstTime)
        let firstFetchCount = await fakeClient.capturedRequests.count
        #expect(firstFetchCount == 2, "First download should fetch both URLs")

        // Second download should return .alreadyDownloaded and skip image re-fetch.
        let secondOutcome = try await deps.downloadForOffline(recipe: recipe)
        #expect(secondOutcome == .alreadyDownloaded)
        let secondFetchCount = await fakeClient.capturedRequests.count
        #expect(
            secondFetchCount == firstFetchCount,
            "Re-download should not trigger additional image fetches"
        )
    }
}

// MARK: - Test Helpers (imported/reused from RatingFetchDegradeTests pattern)

private struct NoopGuestIdentityStore: GuestIdentityStoring {
    func load() throws -> GuestIdentity? { nil }
    func save(_ identity: GuestIdentity) throws {}
    func clear() throws {}
}

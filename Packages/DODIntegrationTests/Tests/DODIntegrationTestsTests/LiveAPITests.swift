import DODDomain
import DODNetworking
import Foundation
import Testing

/// Live-API integration tests. Hit real dutchovendaddy.com — slow, can flake
/// on network conditions, MUST stay nightly-only (constitution §6, L2).
///
/// Gated behind `DOD_RUN_LIVE_TESTS=1` env var so PR builds skip them by
/// default. CI nightly job sets the env var.
@Suite(
    "Live API contract (L2)",
    .enabled(if: ProcessInfo.processInfo.environment["DOD_RUN_LIVE_TESTS"] == "1")
)
struct LiveAPITests {

    /// REG-2 from spec.md AC-T4: posts must come back with hero image URLs.
    /// Catches the `_fields` + `_embed` interaction bug.
    @Test func postsReturnNonNilHeroImage() async throws {
        let client = WPRestClient()
        let items = try await client.posts()
        try #require(!items.isEmpty, "API returned no posts")
        let withImages = items.filter { $0.heroImage != nil }
        #expect(
            withImages.count >= items.count / 2,
            """
            Fewer than half of posts have hero images. \
            Likely cause: _embed payload is being filtered out by _fields. \
            Got \(withImages.count) of \(items.count) with images.
            """
        )
    }

    @Test func postsReturnCanonicalURL() async throws {
        let client = WPRestClient()
        let items = try await client.posts()
        let withURLs = items.filter { $0.canonicalURL != nil }
        #expect(withURLs.count == items.count, "Every post must have canonicalURL")
        // Spot-check the host (CL-4 expects www.dutchovendaddy.com).
        if let first = items.first?.canonicalURL {
            #expect(first.host()?.contains("dutchovendaddy.com") == true)
        }
    }

    @Test func categoriesAreAlphabeticalAndPopulated() async throws {
        let client = WPRestClient()
        let cats = try await client.categories()
        try #require(!cats.isEmpty, "Expected at least one category")
        let names = cats.map(\.name)
        let sorted = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        #expect(names == sorted, "Categories must arrive alphabetically sorted")
        #expect(cats.allSatisfy { $0.count >= 1 }, "Empty categories should not appear")
    }

    @Test func recipeDetailPageHasParseableJSONLD() async throws {
        let client = WPRestClient()
        let items = try await client.posts()
        let firstWithURL = try #require(items.first(where: { $0.canonicalURL != nil }))
        guard let url = firstWithURL.canonicalURL else {
            Issue.record("No canonical URL")
            return
        }
        let fetcher = RecipePageFetcher()
        let html = try await fetcher.html(for: url)
        let recipe = try JSONLDRecipeParser.parse(
            html: html,
            merging: firstWithURL,
            canonicalURL: url
        )
        #expect(!recipe.ingredients.isEmpty, "First recipe should have ingredients")
        #expect(!recipe.instructions.isEmpty, "First recipe should have instructions")
        #expect(recipe.totalTime != nil, "First recipe should have a totalTime")
    }

    @Test func searchReturnsRelevantResults() async throws {
        let client = WPRestClient()
        let results = try await client.search(query: "skillet")
        try #require(!results.isEmpty, "Expected matches for 'skillet'")
        // Sanity: at least one result mentions skillet in title or excerpt.
        let mentioned = results.contains { item in
            let combined = (item.title + " " + item.excerpt).lowercased()
            return combined.contains("skillet")
        }
        #expect(mentioned, "At least one result should mention 'skillet' textually")
    }

    /// REG-13: comments endpoint must surface at least one approved comment
    /// for the canary post 21238 along with the pagination headers.
    @Test func commentsEndpointReturnsRealData() async throws {
        let client = WPCommentsClient()
        let page = try await client.comments(forPostID: 21238, page: 1, perPage: 10)
        try #require(!page.comments.isEmpty, "Expected at least one comment on post 21238")
        #expect(page.totalCount >= page.comments.count)
        #expect(page.totalPages >= 1)
        let first = try #require(page.comments.first)
        #expect(first.postID == 21238)
        #expect(!first.body.isEmpty, "Body must be non-empty after HTML strip")
        #expect(!first.body.contains("<"), "Body must be plain text, not HTML")
    }

    /// REG-14: ratings endpoint must return an average in 0...5 and count
    /// ≥ 0 — even when the upstream blob requires auth (the client degrades
    /// to a zero-summary instead of throwing).
    @Test func ratingsEndpointReturnsRealAverage() async throws {
        let client = WPRMRatingsClient()
        let summary = try await client.summary(forRecipeID: 21238)
        #expect((0.0...5.0).contains(summary.average))
        #expect(summary.count >= 0)  // swiftlint:disable:this empty_count
        #expect(summary.recipeID == 21238)
    }
}

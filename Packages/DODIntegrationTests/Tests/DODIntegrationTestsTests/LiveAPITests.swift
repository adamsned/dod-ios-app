import DODDomain
import DODNetworking
import DODPersistence
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

    /// REG-16 (US-1, T-420): when a recipe is published on
    /// dutchovendaddy.com, the app's feed-load path picks it up on the
    /// next refresh. Asserts the newest post id returned by a direct
    /// `GET /wp/v2/posts?per_page=1&_embed=wp:featuredmedia` is present
    /// in the local `RecipeStore` after the same `WPRestClient.posts()`
    /// call the production `LiveFeedDependencies.fetchPosts(page:)`
    /// wraps + the same `RecipeStore.cache(listItems:)` call
    /// `LiveFeedDependencies.cache(listItems:)` makes from
    /// `FeedViewModel.loadInitial()` (which `FeedViewModel.refresh()`
    /// invokes via `loadInitial(forceReplace: true)`).
    ///
    /// Why a direct `per_page=1` probe in addition to the page-1 batch
    /// fetch: it isolates "what's the newest post id right now?" from
    /// the batch shape that `WPRestClient.posts(page: 1)` returns
    /// (default 20), so a regression on the most-recently-published post
    /// specifically can't hide behind older posts in the batch that
    /// still happen to round-trip cleanly. See CL-43 for the full
    /// rationale.
    @Test func newestPostIsReachableViaFeedRefresh() async throws {
        // Step 1: ask the live blog directly for "what is the newest post?"
        // using the same `_embed=wp:featuredmedia` shape the production
        // `WPRestClient.posts()` call uses (so the assertion is on the same
        // payload shape the app actually consumes).
        let client = WPRestClient()
        let newestBatch = try await client.posts(page: 1, perPage: 1)
        try #require(
            !newestBatch.isEmpty,
            """
            Live blog returned zero posts for per_page=1. Either the blog \
            is in a maintenance window or this test is pointed at a \
            staging URL with no content. REG-16 cannot assert without a \
            newest post to anchor on.
            """
        )
        let newestPost = try #require(newestBatch.first)

        // Step 2: run the production-equivalent feed load. This is the
        // same call `LiveFeedDependencies.fetchPosts(page:)` wraps verbatim
        // (default `page: 1`, default `perPage: 20`), so the assertion
        // exercises the same network shape `FeedViewModel.refresh()` does.
        let feedPage = try await client.posts(page: 1)
        try #require(
            !feedPage.isEmpty,
            "Feed page 1 returned zero posts — REG-16 cannot complete the cache round-trip."
        )

        // Step 3: hand the fetched list to a fresh in-memory `RecipeStore`,
        // exactly the way `LiveFeedDependencies.cache(listItems:)` does in
        // production. Then read back via `RecipeStore.listItems(forIDs:)`
        // — the same accessor `FeedViewModel.loadInitial()` uses to hydrate
        // its `items` array after the cache write.
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        try await store.cache(listItems: feedPage)

        let storedIDs = feedPage.map(\.id)
        let stored = try await store.listItems(forIDs: storedIDs)
        let storedIDSet = Set(stored.map(\.id))

        // The core REG-16 assertion: the newest live post id surfaced in
        // the local store after the production-equivalent refresh path
        // ran. Failure mode would mean a WP REST shape regression on the
        // newest post (e.g. a plugin update broke the `posts` endpoint
        // for just-published posts) — REG-2 doesn't catch this because
        // its half-pass gate can be satisfied by older posts.
        #expect(
            storedIDSet.contains(newestPost.id),
            """
            Newest post id \(newestPost.id) (title: "\(newestPost.title)") was \
            returned by GET /wp/v2/posts?per_page=1 but did NOT appear in the \
            local `RecipeStore` after the production-equivalent \
            `WPRestClient.posts()` + `RecipeStore.cache(listItems:)` round-trip. \
            Possible causes: (a) the newest post fell off the page-1 batch \
            between the two HTTP calls because a new post was published in \
            between — re-run; (b) `RecipeStore.cache(listItems:)` is silently \
            dropping the newest post; (c) the `_embed` payload shape on the \
            newest post specifically is breaking decoding. Investigate the \
            failing payload before assuming a flake.
            """
        )
    }

    /// REG-16 companion (US-1, T-420): the newest live post's `_embed`'d
    /// `wp:featuredmedia` round-trips into a non-nil `heroImage` URL.
    /// REG-2 (`postsReturnNonNilHeroImage`) already asserts this for the
    /// page-1 batch with a "at least half pass" gate, but that gate can
    /// be satisfied by older posts that still round-trip cleanly while a
    /// hero-image regression on the most-recently-published post passes
    /// undetected. REG-16 narrows the assertion onto the single newest
    /// post — the post US-1's AC-1.1 actually cares about for first-glance
    /// app value — on every nightly run. See CL-43.
    @Test func newestPostHasNonNilHeroImage() async throws {
        let client = WPRestClient()
        let newestBatch = try await client.posts(page: 1, perPage: 1)
        try #require(
            !newestBatch.isEmpty,
            """
            Live blog returned zero posts for per_page=1. REG-16 \
            hero-image companion cannot assert without a newest post.
            """
        )
        let newestPost = try #require(newestBatch.first)
        #expect(
            newestPost.heroImage != nil,
            """
            Newest post id \(newestPost.id) (title: "\(newestPost.title)") \
            has a nil `heroImage` on the live API. Likely cause: the \
            `_embed=wp:featuredmedia` payload for the newest post is \
            missing or shaped differently than `WPDTO.Post.inlineHeroURL` \
            expects (e.g. a recently-published post hasn't had its \
            featured-media regenerated by WordPress yet, or a plugin \
            update changed the embed shape). REG-2's half-pass gate \
            wouldn't catch this — older posts in the page-1 batch can \
            still satisfy that gate while a regression on the newest \
            post hides.
            """
        )
    }
}

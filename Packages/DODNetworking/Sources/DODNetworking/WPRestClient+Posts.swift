import DODDomain
import Foundation

extension WPRestClient {

    /// Fetch a page of posts, optionally scoped to a single category.
    /// Used by Feed (T-081) and Category Recipes (T-091) screens.
    ///
    /// Spec trace: AC-1.1, AC-1.2, AC-2.3.
    public func posts(
        categoryID: Int? = nil,
        page: Int = 1,
        perPage: Int = WPRestClient.defaultPageSize
    ) async throws -> [RecipeListItem] {
        try await postsPage(categoryID: categoryID, page: page, perPage: perPage).items
    }

    /// Like ``posts(categoryID:page:perPage:)`` but also returns WP's total
    /// page count (`X-WP-TotalPages`), so paged callers (Feed, Categories) stop
    /// at the real end instead of inferring it from a short page (DUT-237: a
    /// page can return fewer than `perPage` items mid-list, which falsely
    /// latched the feed's "reached end" gate).
    ///
    /// Spec trace: AC-1.1, AC-1.2, AC-2.3, DUT-237.
    public func postsPage(
        categoryID: Int? = nil,
        page: Int = 1,
        perPage: Int = WPRestClient.defaultPageSize
    ) async throws -> (items: [RecipeListItem], totalPages: Int) {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            // `_embed` and `_fields` interact badly: filtering excludes the
            // _links field that drives embedding, so omit _fields here.
            URLQueryItem(name: "_embed", value: "wp:featuredmedia"),
        ]
        if let categoryID {
            queryItems.append(URLQueryItem(name: "categories", value: String(categoryID)))
        }
        let (posts, totalPages): ([WPDTO.Post], Int) = try await getPaged(
            path: "posts",
            queryItems: queryItems
        )
        return (posts.map { $0.toRecipeListItem(heroImage: $0.inlineHeroURL) }, totalPages)
    }

    /// Fetch a single post by its WP id and project it to a
    /// ``RecipeListItem`` (the same lightweight shape `posts()` returns for
    /// list rows). Used by the notification deep-link path (T-632 / US-42):
    /// a notification points at a brand-new post that is **never** in the
    /// local cache, so the tap handler fetches the post here to obtain its
    /// `canonicalURL`, then routes to recipe-detail — which runs the normal
    /// JSON-LD parse / article-classification fetch (AC-4.11 / AC-37.2) to
    /// resolve recipe-vs-article. `_embed=wp:featuredmedia` inlines the
    /// hero image URL so the detail screen has a cell to render immediately,
    /// matching `posts()`.
    ///
    /// Spec trace: REG-20, CL-101 (notification deep-link fetch-on-miss).
    public func post(id: Int) async throws -> RecipeListItem {
        let queryItems: [URLQueryItem] = [
            // `_embed` and `_fields` interact badly: filtering excludes the
            // _links field that drives embedding, so omit _fields here
            // (mirrors `posts()` / `search()`).
            URLQueryItem(name: "_embed", value: "wp:featuredmedia")
        ]
        let post: WPDTO.Post = try await get(path: "posts/\(id)", queryItems: queryItems)
        return post.toRecipeListItem(heroImage: post.inlineHeroURL)
    }

    /// Fetch a single post by its URL **slug**, projecting to a
    /// ``RecipeListItem``. Backs the in-app article recipe-link deep-link
    /// (DOD-ART-2): a round-up article's `<a href>` links are canonical URLs,
    /// not ids, so tapping one resolves the slug here to obtain the post (id +
    /// `canonicalURL`) before routing to recipe-detail.
    ///
    /// Returns `nil` when the slug matches no post — e.g. a link to a WP
    /// *page* (`/about-me/`, `/app-privacy/`) rather than a recipe/article
    /// post — so the caller can fall back to opening the URL in the browser.
    /// `_embed=wp:featuredmedia` inlines the hero image, matching `post(id:)`.
    public func post(slug: String) async throws -> RecipeListItem? {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "slug", value: slug),
            URLQueryItem(name: "_embed", value: "wp:featuredmedia"),
        ]
        let posts: [WPDTO.Post] = try await get(path: "posts", queryItems: queryItems)
        return posts.first.map { $0.toRecipeListItem(heroImage: $0.inlineHeroURL) }
    }

    /// Search posts by query string.
    ///
    /// `perPage` defaults to ``WPRestClient.searchPageSize`` (100, not the
    /// list-endpoint default of 20) so the candidate pool is wide enough
    /// for the post-fetch title-precision filter (T-642 / CL-120) to
    /// catch every title match before the precision step trims body-only
    /// false positives. The pre-T-642 default of 20 dropped the buried
    /// "Cast Iron Skillet Nachos" past the WP relevance-rank cutoff;
    /// widening the pool to 100 means the filter sees all four
    /// title-bearing posts the live API returns for `?search=nachos`.
    /// Net wire impact is one ~50 KB JSON page per typed-and-debounced
    /// query (~3.5× the prior payload) — acceptable for the precision
    /// win because the filter discards most of it client-side and the
    /// existing `URLCache` bypass (CL-50) is unchanged.
    ///
    /// Spec trace: AC-3.1, AC-3.2, CL-120 (Nacho Bug per_page bump), REG-29.
    public func search(
        query: String,
        page: Int = 1,
        perPage: Int = WPRestClient.searchPageSize
    ) async throws -> [RecipeListItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "search", value: trimmed),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            // `_embed` and `_fields` interact badly: filtering excludes the
            // _links field that drives embedding, so omit _fields here.
            URLQueryItem(name: "_embed", value: "wp:featuredmedia"),
        ]
        let posts: [WPDTO.Post] = try await get(path: "posts", queryItems: queryItems)
        return posts.map { $0.toRecipeListItem(heroImage: $0.inlineHeroURL) }
    }
}

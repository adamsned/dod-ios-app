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
        // DUT-575: decode the page lossily so a single malformed post (e.g.
        // `title: null`) is skipped instead of emptying the whole feed.
        let (lossy, totalPages): (LossyArray<WPDTO.Post>, Int) = try await getPaged(
            path: "posts",
            queryItems: queryItems
        )
        return (lossy.elements.map { $0.toRecipeListItem(heroImage: $0.inlineHeroURL) }, totalPages)
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
        // DUT-575: lossy decode — a malformed sibling row must not fail the slug lookup.
        let lossy: LossyArray<WPDTO.Post> = try await get(path: "posts", queryItems: queryItems)
        return lossy.elements.first.map { $0.toRecipeListItem(heroImage: $0.inlineHeroURL) }
    }

    /// The WP Recipe Maker recipe custom-post-type. Its `X-WP-Total` is the
    /// count of *real recipes* — round-up / guide articles are plain posts with
    /// NO `wprm_recipe`, so sampling this set (rather than `posts`) makes
    /// "Surprise Me" land only on something cookable.
    static let recipeCPTPath = "wprm_recipe"

    /// Reroll budget for ``randomPost()`` — enough to skip the rare empty slot
    /// (a recipe deleted between the count and the fetch), an orphaned recipe
    /// (no parent post), or an unpublished parent (404), without ever looping
    /// unbounded on a misbehaving catalog.
    static let randomRecipeMaxAttempts = 4

    /// Fetch ONE uniformly-random RECIPE from the whole catalog, projected to a
    /// ``RecipeListItem`` — the same shape `posts()` / `post(id:)` return — for
    /// the Feed's + Search's "Surprise Me" button (DUT-1062).
    ///
    /// Why not `orderby=rand`: the pre-fix implementation asked WP for
    /// `orderby=rand`, but core WordPress REST rejects that value
    /// (`rest_invalid_param`, HTTP 400 — `orderby` is a fixed enum), so every
    /// tap silently fell through to the view model's in-memory sample (~20-40
    /// recently-scrolled recipes). Older recipes never surfaced.
    ///
    /// How it works instead (no server change required):
    /// 1. Read `X-WP-Total` for the ``recipeCPTPath`` set — the definitive
    ///    "real recipes" count (articles are excluded, being post-only).
    /// 2. Roll a random `offset` in `[0, total)` and fetch that single
    ///    `wprm_recipe`, reading its `wprm_parent_post_id` (the blog post the
    ///    recipe belongs to — returned as a string).
    /// 3. Resolve that post through the existing ``post(id:)`` path so the
    ///    returned item is byte-identical to a normal feed tap (hero image,
    ///    canonical URL, classification inputs).
    ///
    /// Rerolls (bounded by ``randomRecipeMaxAttempts``) skip an empty slot, an
    /// orphaned recipe, or an unpublished parent. Throws
    /// ``WPClientError/underlying(message:)`` when the count is unavailable or
    /// every attempt misses — the view-model caller then falls back to sampling
    /// the in-memory feed rather than leaving the button dead.
    ///
    /// Spec trace: DUT-1062.
    public func randomPost() async throws -> RecipeListItem {
        guard
            let total = try await totalCount(
                path: Self.recipeCPTPath,
                queryItems: [
                    URLQueryItem(name: "per_page", value: "1"),
                    URLQueryItem(name: "_fields", value: "id"),
                ]
            ),
            total > 0
        else {
            throw WPClientError.underlying(message: "No recipes available for a random pick")
        }

        for _ in 0..<Self.randomRecipeMaxAttempts {
            let offset = Int.random(in: 0..<total)
            let refs: [RecipeParentRef] = try await get(
                path: Self.recipeCPTPath,
                queryItems: [
                    URLQueryItem(name: "per_page", value: "1"),
                    URLQueryItem(name: "offset", value: String(offset)),
                    URLQueryItem(name: "_fields", value: "wprm_parent_post_id"),
                ]
            )
            // Empty slot (raced deletion) or an orphaned/draft recipe whose
            // parent id is missing / non-numeric / zero — reroll.
            guard let parentID = refs.first?.parentPostID, parentID > 0 else { continue }
            do {
                return try await post(id: parentID)
            } catch WPClientError.httpStatus(404) {
                // Parent post unpublished/removed since indexing — reroll.
                continue
            }
        }
        throw WPClientError.underlying(
            message: "Could not resolve a random recipe in \(Self.randomRecipeMaxAttempts) attempts"
        )
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
        // DUT-575: lossy decode so one malformed search hit can't empty the results.
        let lossy: LossyArray<WPDTO.Post> = try await get(path: "posts", queryItems: queryItems)
        return lossy.elements.map { $0.toRecipeListItem(heroImage: $0.inlineHeroURL) }
    }
}

/// Minimal projection of a `wprm_recipe` row: just the id of the blog post the
/// recipe belongs to, which WP Recipe Maker stores (and returns) as a STRING
/// (e.g. `"15346"`). Backs ``WPRestClient/randomPost()``'s recipe → post
/// resolution (DUT-1062).
private struct RecipeParentRef: Decodable {

    /// The parent post id, or `nil` when it is missing, empty, non-numeric, or
    /// zero — i.e. an orphaned recipe the caller should reroll past.
    let parentPostID: Int?

    private enum CodingKeys: String, CodingKey {
        case wprmParentPostID = "wprm_parent_post_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // WPRM returns the id as a string; tolerate a numeric form too.
        if let raw = try? container.decode(String.self, forKey: .wprmParentPostID) {
            parentPostID = Int(raw)
        } else if let numeric = try? container.decode(Int.self, forKey: .wprmParentPostID) {
            parentPostID = numeric
        } else {
            parentPostID = nil
        }
    }
}

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
        let posts: [WPDTO.Post] = try await get(path: "posts", queryItems: queryItems)
        return posts.map { $0.toRecipeListItem(heroImage: $0.inlineHeroURL) }
    }

    /// Search posts by query string.
    ///
    /// Spec trace: AC-3.1, AC-3.2.
    public func search(
        query: String,
        page: Int = 1,
        perPage: Int = WPRestClient.defaultPageSize
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

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
            URLQueryItem(name: "_fields", value: "id,slug,link,title,excerpt,date,featured_media,categories"),
        ]
        if let categoryID {
            queryItems.append(URLQueryItem(name: "categories", value: String(categoryID)))
        }
        let posts: [WPDTO.Post] = try await get(path: "posts", queryItems: queryItems)
        return posts.map { $0.toRecipeListItem(heroImage: nil) }
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
            URLQueryItem(name: "_fields", value: "id,slug,link,title,excerpt,date,featured_media,categories"),
        ]
        let posts: [WPDTO.Post] = try await get(path: "posts", queryItems: queryItems)
        return posts.map { $0.toRecipeListItem(heroImage: nil) }
    }
}

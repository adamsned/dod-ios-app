import DODDomain
import DODNetworking
import Foundation

// T-791 file-length trim: extracted the article/slug recipe-resolution helpers
// from AppDependencies.swift to keep that file under the SwiftLint
// `file_length` cap after the DUT-78 crash-loop self-heal launch wiring landed.
// No behavior change — these were already methods on `AppDependencies`.
extension AppDependencies {

    /// Fetch a single post (by WP id) from the live REST API and project it
    /// to a ``RecipeListItem``. Backs the notification deep-link fetch-on-
    /// cache-miss path (T-632 / REG-20 / CL-101): a notification targets a
    /// brand-new post that is never cached, so `RootView.resolveRecipeRoute`
    /// calls this when `store.recipeWithoutTouching(id:)` misses, then routes
    /// to recipe-detail (which runs the JSON-LD parse / article
    /// classification to resolve recipe-vs-article per AC-4.11 / AC-37.2).
    func fetchListItem(forPostID id: Int) async throws -> RecipeListItem {
        try await restClient.post(id: id)
    }

    /// Resolve a tapped article link (a `dutchovendaddy.com` canonical URL) to
    /// a ``RecipeListItem`` by its slug — backs the in-app article recipe-link
    /// deep-link (DOD-ART-2). Returns `nil` for an off-site URL, or a
    /// `dutchovendaddy.com` URL whose slug matches no recipe/article post (a WP
    /// *page* like `/about-me/`), so `RootView` falls back to the browser.
    /// Best-effort: a network failure also yields `nil`.
    func resolveRecipe(forArticleLink url: URL) async -> RecipeListItem? {
        guard let slug = Self.recipeSlug(fromDODURL: url) else { return nil }
        return try? await restClient.post(slug: slug)
    }

    /// Extract the post slug from a `https://(www.)dutchovendaddy.com/<slug>/`
    /// permalink (DOD uses flat `/<slug>/` permalinks), or `nil` for any other
    /// host. The slug is the first non-empty path component.
    static func recipeSlug(fromDODURL url: URL) -> String? {
        guard
            let host = url.host()?.lowercased(),
            host == "dutchovendaddy.com" || host == "www.dutchovendaddy.com"
        else {
            return nil
        }
        return url.pathComponents.first { $0 != "/" && !$0.isEmpty }
    }
}

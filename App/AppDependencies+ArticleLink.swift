import DODDomain
import DODNetworking
import Foundation

/// In-app article recipe-link resolution (DOD-ART-2 / DUT-920). Split out of
/// `AppDependencies.swift` to keep that file under the SwiftLint `file_length`
/// cap; the redirect-follow policy itself lives in ``ArticleLinkResolver``.
extension AppDependencies {

    /// Resolve a tapped article link (a `dutchovendaddy.com` canonical URL) to
    /// a ``RecipeListItem`` by its slug — backs the in-app article recipe-link
    /// deep-link (DOD-ART-2). Returns `nil` for an off-site URL, or a
    /// `dutchovendaddy.com` URL whose slug matches no recipe/article post (a WP
    /// *page* like `/about-me/`), so `RootView` falls back to the browser.
    /// Best-effort: a network failure also yields `nil`.
    ///
    /// DUT-920: on an exact-slug miss, follows the link's redirect (a renamed
    /// recipe 301-redirects its old slug to the new one) and retries with the
    /// resolved slug before giving up — see ``ArticleLinkResolver``.
    func resolveRecipe(forArticleLink url: URL) async -> RecipeListItem? {
        await ArticleLinkResolver.resolve(
            url: url,
            slug: { Self.recipeSlug(fromDODURL: $0) },
            postLookup: { [restClient] slug in try await restClient.post(slug: slug) },
            followRedirect: redirectResolver
        )
    }

    /// Extract the post slug from a `https://(www.)dutchovendaddy.com/<slug>/`
    /// permalink (DOD uses flat `/<slug>/` permalinks), or `nil` for any other
    /// host. The slug is the first non-empty path component.
    ///
    /// `nonisolated` — a pure URL transform with no actor state, so
    /// ``ArticleLinkResolver``'s `slug` closure (invoked off the main actor) and
    /// the `@MainActor` `RootView` link-routing callers can both reach it.
    nonisolated static func recipeSlug(fromDODURL url: URL) -> String? {
        guard
            let host = url.host()?.lowercased(),
            host == "dutchovendaddy.com" || host == "www.dutchovendaddy.com"
        else {
            return nil
        }
        return url.pathComponents.first { $0 != "/" && !$0.isEmpty }
    }
}

import DODDomain
import Foundation

/// Resolves a tapped in-app article link (a `dutchovendaddy.com` permalink) to
/// its ``RecipeListItem``, following a 301 redirect when the exact-slug lookup
/// misses (DUT-920).
///
/// ## Why this exists as a standalone type
/// The resolution policy used to live inline in
/// `AppDependencies.resolveRecipe(forArticleLink:)` as a single exact-slug
/// `WPRestClient.post(slug:)` lookup. When a recipe is **renamed**, WordPress
/// 301-redirects the old slug to the new one, but the REST `?slug=` query is
/// exact — the old slug matches no post, the lookup returns `nil`, and the
/// in-app tap silently falls back to the system browser (DUT-920: e.g.
/// `dutch-oven-ham-and-bean-soup` → `dutch-oven-ham-and-bean-soup-tomato-based`,
/// post id 4478).
///
/// Lifting the policy out of `AppDependencies` (which is a `@MainActor`
/// composition root with a heavyweight `init`) makes every branch unit-testable
/// in-process: the three I/O edges — slug extraction, the REST slug lookup, and
/// the redirect follow — are injected as closures, so no network and no
/// `AppDependencies` construction are needed to drive the resolution logic.
///
/// ## Resolution order
/// 1. Exact-slug lookup. On a hit, return it — the happy path pays **zero**
///    extra network cost (unchanged from the pre-DUT-920 behavior).
/// 2. On a miss, follow the link's redirect (URLSession follows 301s by
///    default, so the resolved URL is `response.url`).
/// 3. If the resolved slug differs from the original, retry the lookup with it.
/// 4. Still `nil` (no redirect, an off-site redirect, an unchanged slug, or a
///    second miss) → `nil`, and the caller falls back to the browser.
enum ArticleLinkResolver {

    /// Resolve `url` into a ``RecipeListItem``, or `nil` when the link is not a
    /// resolvable recipe/article post (an off-site URL, a WP *page* like
    /// `/about-me/`, or a network failure — all browser-fallback cases).
    ///
    /// - Parameters:
    ///   - url: the tapped `dutchovendaddy.com` permalink.
    ///   - slug: extracts the post slug from a DOD URL, or `nil` for any other
    ///     host. Mirrors `AppDependencies.recipeSlug(fromDODURL:)`.
    ///   - postLookup: exact-slug REST lookup returning the post, or `nil` when
    ///     the slug matches no post. Mirrors `WPRestClient.post(slug:)`.
    ///   - followRedirect: follows the URL's redirect chain and returns the
    ///     final URL, or `nil` on failure. Mirrors a default `URLSession` GET.
    static func resolve(
        url: URL,
        slug: @Sendable (URL) -> String?,
        postLookup: @Sendable (String) async throws -> RecipeListItem?,
        followRedirect: @Sendable (URL) async -> URL?
    ) async -> RecipeListItem? {
        guard let originalSlug = slug(url) else { return nil }
        // Happy path: exact-slug hit, no redirect follow, zero extra network.
        if let item = try? await postLookup(originalSlug) {
            return item
        }
        // Miss — the recipe may have been renamed (its old slug 301-redirects to
        // the new one). Follow the redirect and retry only if the slug changed.
        guard
            let resolvedURL = await followRedirect(url),
            let resolvedSlug = slug(resolvedURL),
            resolvedSlug != originalSlug
        else {
            return nil
        }
        return try? await postLookup(resolvedSlug)
    }
}

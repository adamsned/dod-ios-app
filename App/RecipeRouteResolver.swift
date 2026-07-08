import DODDomain
import DODPersistence
import DODSupport
import Foundation

/// Resolves a deep-link recipe/post id into a ``RecipeRoute`` for the
/// Feed tab's NavigationStack, with **fetch-on-cache-miss** semantics.
///
/// Spec trace: T-632 / REG-20 / CL-101 (notification deep-link fetch).
///
/// ## Why this exists as a standalone type
/// `RootView.resolveRecipeRoute(id:autoStartCookMode:)` used to be a private
/// `View` method doing a single cache-only lookup
/// (`store.recipeWithoutTouching(id:)`) and returning `nil` on a miss. That
/// is correct for widget/Spotlight deep links — those always point at an
/// already-cached recipe — but it silently dropped **notification** deep
/// links, which point at brand-new posts that are *never* cached. The whole
/// point of US-42 notifications is announcing NEW posts, so the cache-only
/// path made the feature inert for its real use case (T-631 / US-42).
///
/// The resolution policy is lifted out of the `View` so it is unit-testable
/// without a SwiftUI host: the two I/O edges (cache lookup + remote fetch)
/// are injected as closures, and the article-vs-recipe distinction is left
/// to the recipe-detail screen the route lands on.
///
/// ## Article vs. recipe routing
/// Both kinds route through ``RecipeRoute/recipe(item:autoStartCookMode:)``.
/// `RecipeDetailViewModel.fetchAndParse()` runs the JSON-LD parse and, on
/// parse failure, falls back to article-body extraction — transitioning to
/// the `.article` load state which `RecipeDetailView` renders via
/// `ArticleDetailView` (US-37 / CL-63 / AC-37.2). So routing an article's
/// `RecipeListItem` (carrying its `canonicalURL`) to `.recipe(item:)`
/// *does* open the article detail; PostKind is honored by the detail
/// screen's existing classification, not by a separate route case. This is
/// the same hydration path a normal feed-row tap takes for an uncached
/// recipe — we reuse it rather than reinventing a parallel one.
enum RecipeRouteResolver {

    /// Resolve `id` into a route, preferring the local cache and falling
    /// back to a network fetch on a miss.
    ///
    /// - Parameters:
    ///   - id: the WP post id from the deep link.
    ///   - autoStartCookMode: forwarded into the resulting recipe route
    ///     (set by `StartCookModeIntent`, US-10).
    ///   - cachedLookup: returns the cached ``Recipe`` for `id`, or `nil`
    ///     if it is not cached. Mirrors `store.recipeWithoutTouching(id:)`
    ///     (must NOT bump the recently-viewed LRU — REG-10).
    ///   - fetch: fetches the post from the REST API as a ``RecipeListItem``
    ///     (carrying `canonicalURL`). Mirrors
    ///     `AppDependencies.fetchListItem(forPostID:)`.
    /// - Returns: a ``RecipeRoute`` to push, or `nil` when the id is
    ///   unresolvable (not cached **and** the fetch failed — a post that
    ///   truly doesn't exist or whose detail can't be hydrated). The
    ///   caller treats `nil` as "ignore this deep link" (the graceful
    ///   fallback preserved from the original cache-only behavior).
    static func resolve(
        id: Int,
        autoStartCookMode: Bool,
        cachedLookup: sending (Int) async throws -> Recipe?,
        fetch: sending (Int) async throws -> RecipeListItem
    ) async -> RecipeRoute? {
        // Cache-first: widgets / Spotlight always hit here, so their
        // behavior is unchanged (no network, no LRU touch).
        if let cached = try? await cachedLookup(id) {
            // DUT-670 — build the list item from the cached `Recipe` directly so
            // its real `publishedAt` + a formatted `totalTimeDisplay` survive. The
            // old `RecipeEntityPayload.fromRecipe(cached).toListItem()` hop dropped
            // both (hardcoded `.distantPast` / `nil`), so the pushed detail row lost
            // its date + cook-time chip on a cache hit.
            let item = listItem(fromCached: cached)
            return .recipe(item: item, autoStartCookMode: autoStartCookMode)
        }

        // Cache miss — the notification case. Fetch the post by id so we
        // have its canonicalURL, then route to recipe-detail, which runs
        // the JSON-LD parse / article classification (recipe → recipe
        // detail, article → ArticleDetailView).
        do {
            let item = try await fetch(id)
            return .recipe(item: item, autoStartCookMode: autoStartCookMode)
        } catch {
            // The post truly doesn't exist, or the fetch failed. Keep the
            // graceful "ignore" fallback (CL-9 / AC-4.11) — distinct log
            // line so a fetch failure is diagnosable separately from a
            // plain cache miss.
            DODLog.app.error("deep link: recipe \(id) fetch failed: \(String(describing: error))")
            return nil
        }
    }

    /// DUT-670 — map a cached ``Recipe`` to the ``RecipeListItem`` the detail
    /// route carries, preserving `publishedAt` and formatting `totalTime` into
    /// `totalTimeDisplay` (the two fields the old `RecipeEntityPayload` hop lost).
    private static func listItem(fromCached recipe: Recipe) -> RecipeListItem {
        RecipeListItem(
            id: recipe.id,
            title: recipe.title,
            excerpt: recipe.excerpt,
            heroImage: recipe.heroImage,
            publishedAt: recipe.publishedAt,
            // DUT-670 — mirror a fresh REST list item's time chip on a cache hit.
            // Uses the shared DODPersistence `formatTime` (previously a byte-for-byte
            // private copy here); the `Duration`→whole-seconds conversion matches the
            // persistence layer's `Int(duration.components.seconds)` exactly, so the
            // rendered chip ("30 min" / "1 hr 15 min") is unchanged.
            totalTimeDisplay: recipe.totalTime.flatMap {
                formatTime(seconds: Int($0.components.seconds))
            },
            canonicalURL: recipe.canonicalURL
        )
    }

    /// DUT-549 — the caller-facing outcome of a resolve: a route to push, or an
    /// explicit failure the caller must surface. Splitting the `nil`-means-failed
    /// convention into a named case lets the routing layer (`RootView`) show a
    /// "couldn't open that recipe" toast instead of silently dumping the user on
    /// a blank Feed, and keeps that decision unit-testable without a SwiftUI host.
    enum DeepLinkResolveOutcome: Equatable {
        case route(RecipeRoute)
        case failed
    }

    /// Map a resolved (possibly `nil`) route to a ``DeepLinkResolveOutcome``. A
    /// `nil` route — the id is neither cached nor fetchable — becomes `.failed`
    /// so the caller surfaces feedback (DUT-549) rather than a dead tap.
    static func outcome(for route: RecipeRoute?) -> DeepLinkResolveOutcome {
        guard let route else { return .failed }
        return .route(route)
    }
}

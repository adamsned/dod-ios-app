import DODDomain
import DODSupport
import Foundation

/// Merge REST search results with local ingredient-index matches into a
/// single, deduped, rank-ordered list — gated on a **title-precision
/// filter** so body-only WP matches never surface as search results.
///
/// Ranking (highest first):
///   1. REST hit whose title **exactly** matches the query (normalized).
///   2. REST hit whose title **contains** the query as a contiguous
///      substring (normalized; case/punct insensitive).
///   3. REST hit whose title fuzzy-matches the query (plural/singular
///      swap or Levenshtein-1 against any title token).
///   4. Local **ingredient** hit (recipe was indexed and an ingredient
///      line contains the query) that the REST pass missed.
///
/// Within each tier the original order from the source array is preserved
/// (REST tier preserves WP's own relevance/recency ordering; the local tier
/// preserves whatever the SwiftData fetch returned). Duplicates across tiers
/// are dropped at the first tier they appear in.
///
/// **CL-120 / T-642 / REG-29 — Nacho Bug fix.** The pre-T-642 merger
/// admitted any REST hit (title-or-not) into the "excerpt" tier on the
/// assumption that WP's relevance ranker had already filtered noise.
/// That assumption broke for short, common-word queries like "nachos"
/// where WP's body-search surfaced 17 false positives (Birria, Skillet
/// Cookie, Tequila Lime Chicken, Bacon Wrapped Pickles, etc.) plus only
/// 3 real title matches per page, while a fourth real title match
/// ("Cast Iron Skillet Nachos") got buried past the 20-row cutoff. The
/// fix here is the precision half: every REST candidate is run through
/// `TitleSearchMatcher.match(query:title:)` and only the title-bearing
/// ones survive. The per_page bump in `WPRestClient.searchPageSize`
/// (CL-120 sibling) is the recall half — together, the four known
/// title matches for `?search=nachos` lift back into the visible set
/// and the 17 body-only false positives drop.
///
/// **v2 Search overhaul (2/3) — content matches survive.** CL-120's
/// title-precision filter still governs the PRIMARY tier (`items`): a
/// title-bearing hit ranks above a body-only one, and the tier order
/// (exact → substring → fuzzy) is unchanged. What changed is that the
/// body-only WP hits are no longer *discarded* — the server's
/// `?search=<q>` endpoint searches recipe CONTENT (ingredients, method),
/// so those hits are the catalog-wide "recipes that USE this term". They
/// now ride out of ``partition(query:restResults:)`` as
/// `contentMatches`, which the view model surfaces as the labeled
/// "Recipes Using <term>" tier beneath the title tier. Searching an
/// ingredient ("buttermilk", "ground beef") therefore returns the recipes
/// that use it, in WP's own relevance order, instead of only the handful
/// with the term in the title.
///
/// `merge(query:restResults:localIngredientResults:)` is preserved as a
/// thin wrapper returning only the title tier so the many existing
/// merger call sites / tests keep their exact contract; the pipeline
/// itself now calls ``partition(query:restResults:)`` to get both tiers.
///
/// Spec trace: US-12 / AC-12.1 (ingredient-aware ranking), AC-12.6
/// (REG-12 — unit tests on the merger), CL-120 / REG-29 / T-642
/// (title-precision ordering, preserved), v2 Search overhaul (2/3)
/// (content-match survival, the change here).
public enum SearchResultMerger {

    /// The two relevance tiers of a `?search=<q>` response.
    ///
    /// - `titleMatches`: REST hits whose title matches the query, tier-
    ///   ordered (exact → substring → fuzzy), WP order preserved within a
    ///   tier. Backs the primary `items` result list.
    /// - `contentMatches`: the remaining REST hits — the ones WP returned
    ///   for a body/ingredient match but whose title does NOT match. In
    ///   WP's own relevance order (ties by date). Backs the "Recipes
    ///   Using <term>" tier. Deduped against the title tier by id.
    public struct Partition: Sendable, Equatable {
        public let titleMatches: [RecipeListItem]
        public let contentMatches: [RecipeListItem]

        public init(titleMatches: [RecipeListItem], contentMatches: [RecipeListItem]) {
            self.titleMatches = titleMatches
            self.contentMatches = contentMatches
        }
    }

    /// Split a `?search=<q>` REST response into the title tier and the
    /// content (body/ingredient) tier. Both tiers are deduped by id — an
    /// id that title-matches never also appears in `contentMatches`, and a
    /// duplicate row (same id twice in the input) is collapsed at first
    /// sight. Pure value-type function; no I/O.
    public static func partition(
        query: String,
        restResults: [RecipeListItem]
    ) -> Partition {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            // Degenerate query (whitespace-only after trim) — the REST
            // call already short-circuited at the client, so this path
            // is only reachable in test fixtures.
            return Partition(titleMatches: [], contentMatches: [])
        }

        // Tier the title matches (carrying their kind so the final sort is
        // a single stable pass) and collect the body-only hits separately,
        // preserving WP's relevance order in both.
        var titleMatches: [(item: RecipeListItem, kind: TitleMatchKind)] = []
        var contentMatches: [RecipeListItem] = []
        var seen: Set<Int> = []

        for item in restResults where !seen.contains(item.id) {
            seen.insert(item.id)
            if let kind = TitleSearchMatcher.match(query: needle, title: item.title) {
                titleMatches.append((item, kind))
            } else {
                // v2 Search overhaul (2/3): a body-only / ingredient WP
                // hit. No longer discarded — it's a catalog-wide "recipe
                // that USES this term" and rides out as a content match.
                contentMatches.append(item)
            }
        }

        // Stable sort by tier (exact < substring < fuzzy). Within a tier,
        // preserve the WP relevance/recency ordering that `restResults`
        // arrived in. `Array.sorted(by:)` is documented stable as of
        // Swift 5.0, so equal tiers keep their source-order positions.
        let ordered =
            titleMatches
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.kind != rhs.element.kind {
                    return lhs.element.kind < rhs.element.kind
                }
                return lhs.offset < rhs.offset
            }
            .map { $0.element.item }

        return Partition(titleMatches: ordered, contentMatches: contentMatches)
    }

    /// Title-tier-only merge, preserved for source-compat with the
    /// existing call sites/tests. Delegates to ``partition(query:restResults:)``
    /// and returns just the title tier. `localIngredientResults` is
    /// ignored here — the view-model pipeline folds the local ingredient
    /// index into the "Recipes Using <term>" tier alongside the server
    /// content matches (see `SearchViewModel.finishTextSearch`).
    public static func merge(
        query: String,
        restResults: [RecipeListItem],
        localIngredientResults: [RecipeListItem]
    ) -> [RecipeListItem] {
        _ = localIngredientResults
        return partition(query: query, restResults: restResults).titleMatches
    }
}

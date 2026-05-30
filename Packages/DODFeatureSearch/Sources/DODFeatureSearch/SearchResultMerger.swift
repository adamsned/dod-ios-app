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
/// **v1 deferral of the local-ingredient pass.** Per CL-120, the
/// local-ingredient surface is dropped from the merged set for v1 of
/// this fix — the title-precision contract is the user's primary
/// complaint and ingredient-search is its own feature surface in
/// dad's broader "Make search way better" backlog entry. The
/// `localIngredientResults` parameter is preserved on the signature
/// for source-compat with the existing call site in
/// `SearchViewModel.performSearch()`; the v1 implementation simply
/// ignores it. A future task can re-introduce the ingredient tier as
/// a labeled section below the title tiers without changing this
/// signature.
///
/// Spec trace: US-12 / AC-12.1 (ingredient-aware ranking, v1-deferred
/// half), AC-12.6 (REG-12 — unit tests on the merger), CL-120 /
/// REG-29 / T-642 (title-precision filter, the change here).
public enum SearchResultMerger {

    public static func merge(
        query: String,
        restResults: [RecipeListItem],
        localIngredientResults: [RecipeListItem]
    ) -> [RecipeListItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            // Degenerate query (whitespace-only after trim) — the REST
            // call already short-circuited at the client, so this path
            // is only reachable in test fixtures. Return nothing; the
            // empty-state UI handles the rest.
            return []
        }

        // Tier results carry their per-item match kind so the final
        // sort is a single stable pass by (tier, original index).
        var titleMatches: [(item: RecipeListItem, kind: TitleMatchKind)] = []
        var seen: Set<Int> = []

        for item in restResults where !seen.contains(item.id) {
            if let kind = TitleSearchMatcher.match(query: needle, title: item.title) {
                titleMatches.append((item, kind))
                seen.insert(item.id)
            }
            // Body-only / fuzzier WP hits are intentionally dropped per
            // CL-120 / REG-29 — the user's contract is title-precision.
        }

        // Stable sort by tier (exact < substring < fuzzy). Within a
        // tier, preserve the WP relevance/recency ordering that
        // `restResults` arrived in. Note: `Array.sorted(by:)` is
        // documented stable as of Swift 5.0, so equal tiers keep
        // their source-order positions.
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

        // CL-120 v1 deferral: ignore `localIngredientResults` here.
        // The parameter survives on the signature so the call site at
        // `SearchViewModel.performSearch()` is untouched and a future
        // task can re-enable the tier as a labeled section.
        _ = localIngredientResults
        return ordered
    }
}

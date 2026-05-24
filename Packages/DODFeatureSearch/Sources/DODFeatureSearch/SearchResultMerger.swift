import DODDomain
import Foundation

/// Merge REST search results with local ingredient-index matches into a
/// single, deduped, rank-ordered list.
///
/// Ranking (highest first):
///   1. REST hit where the **title** contains the query (case-insensitive).
///   2. REST hit where the **excerpt** contains the query, OR a REST hit
///      that didn't match title/excerpt literally (WP search is fuzzier
///      than `contains`) — treated as the excerpt tier so it still ranks
///      above local-only ingredient hits.
///   3. Local **ingredient** hit (recipe was indexed and an ingredient
///      line contains the query) that the REST pass missed.
///
/// Within each tier the original order from the source array is preserved
/// (REST tier preserves WP's own relevance/recency ordering; the local tier
/// preserves whatever the SwiftData fetch returned). Duplicates across tiers
/// are dropped at the first tier they appear in.
///
/// Spec trace: US-12 / AC-12.1 (ingredient-aware ranking),
/// AC-12.6 (REG-12 — unit tests on the merger).
public enum SearchResultMerger {

    public static func merge(
        query: String,
        restResults: [RecipeListItem],
        localIngredientResults: [RecipeListItem]
    ) -> [RecipeListItem] {
        let needle = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            // Fall back to a trivial merge — preserve REST order, append any
            // local hit not already present.
            return appending(localIngredientResults, after: restResults)
        }

        var titleHits: [RecipeListItem] = []
        var excerptHits: [RecipeListItem] = []
        var seen: Set<Int> = []

        for item in restResults where !seen.contains(item.id) {
            if item.title.lowercased().contains(needle) {
                titleHits.append(item)
                seen.insert(item.id)
            } else {
                // Either excerpt-contains or WP returned it for a fuzzier
                // reason — either way it ranks above local-only hits.
                excerptHits.append(item)
                seen.insert(item.id)
            }
        }

        var ingredientHits: [RecipeListItem] = []
        for item in localIngredientResults where !seen.contains(item.id) {
            ingredientHits.append(item)
            seen.insert(item.id)
        }

        return titleHits + excerptHits + ingredientHits
    }

    private static func appending(
        _ additions: [RecipeListItem],
        after base: [RecipeListItem]
    ) -> [RecipeListItem] {
        var seen = Set(base.map(\.id))
        var combined = base
        for item in additions where !seen.contains(item.id) {
            combined.append(item)
            seen.insert(item.id)
        }
        return combined
    }
}

import Foundation

/// Pure helper backing the search field's type-ahead suggestions (v2 Search
/// overhaul 2/3). Given the query prefix the user has typed and a pool of
/// recipe titles, it returns the best-matching titles to show under the field
/// BEFORE the (slower) result fetch settles.
///
/// Why this lives in `DODSupport` (not `DODFeatureSearch`): like
/// ``TitleSearchMatcher`` and ``SearchSuggestionEngine``, it's a pure
/// Foundation-only value function that a future surface (Spotlight, App
/// Intents) could reuse, and it shares `TitleSearchMatcher`'s normalization so
/// autocomplete and result matching agree on how a title reads.
///
/// Ranking (strongest first), ties broken by the pool's own order:
///   1. Title whose normalized form STARTS WITH the query (whole-title prefix).
///   2. Title where a WORD starts with the query (word-boundary prefix).
///   3. Title that merely CONTAINS the query as a substring.
/// Titles that don't contain the query at all are excluded. Duplicate titles
/// (case/whitespace-insensitively equal) collapse to their first occurrence.
public enum SearchAutocomplete {

    /// Minimum normalized-query length before any suggestion is produced —
    /// matches ``TitleSearchMatcher/minimumQueryLength`` so a 1-char query
    /// (which matches nearly everything) never fans out noise.
    public static let minimumQueryLength = 2

    private enum Tier: Int {
        case titlePrefix = 0
        case wordPrefix = 1
        case substring = 2
    }

    /// A candidate title with its match tier and its position in the source
    /// pool (the tie-breaker). A named type rather than a 3-tuple (SwiftLint
    /// `large_tuple`).
    private struct Ranked {
        let title: String
        let tier: Tier
        let offset: Int
    }

    /// The best `limit` title suggestions for `query` from `titles`, in rank
    /// order. Returns the ORIGINAL (un-normalized) title strings so the UI
    /// shows them exactly as authored.
    public static func suggestions(
        query: String,
        titles: [String],
        limit: Int
    ) -> [String] {
        guard limit > 0 else { return [] }
        let needle = TitleSearchMatcher.normalize(query)
        guard needle.count >= minimumQueryLength else { return [] }

        var ranked: [Ranked] = []
        var seenNormalized: Set<String> = []

        for (offset, title) in titles.enumerated() {
            let normalized = TitleSearchMatcher.normalize(title)
            guard !normalized.isEmpty, !seenNormalized.contains(normalized) else { continue }
            guard let tier = tier(needle: needle, normalizedTitle: normalized) else { continue }
            seenNormalized.insert(normalized)
            ranked.append(Ranked(title: title, tier: tier, offset: offset))
        }

        return
            ranked
            .sorted { lhs, rhs in
                if lhs.tier != rhs.tier { return lhs.tier.rawValue < rhs.tier.rawValue }
                return lhs.offset < rhs.offset
            }
            .prefix(limit)
            .map(\.title)
    }

    /// The strongest tier at which `normalizedTitle` matches `needle`, or nil.
    private static func tier(needle: String, normalizedTitle: String) -> Tier? {
        if normalizedTitle.hasPrefix(needle) { return .titlePrefix }
        let words = normalizedTitle.split(separator: " ").map(String.init)
        if words.contains(where: { $0.hasPrefix(needle) }) { return .wordPrefix }
        if normalizedTitle.contains(needle) { return .substring }
        return nil
    }
}

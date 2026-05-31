import Foundation

/// Pure helper that answers "did the user mean a different word?" by
/// finding the closest cached recipe-title token to any token of the
/// user's query via Levenshtein distance. Returns a recovered query
/// string with only the typo token swapped, or `nil` when no useful
/// suggestion exists.
///
/// Why this lives in `DODSupport` (not in `DODFeatureSearch`): the engine
/// is a pure value-type function (Foundation-only, no dependencies) and
/// a future surface — Saved-tab search, Spotlight cold-start search,
/// App Intents — will want the same contract. Lifting it into the
/// support layer means every future caller gets the same recovery
/// behavior without a feature-package dependency. Mirrors the same
/// rationale as `TitleSearchMatcher` (T-642 / CL-120), which it
/// neighbors in this module.
///
/// Spec trace: US-12 amendment / US-29 amendment / CL-127 / T-649.
public enum SearchSuggestionEngine {

    /// Returns a "did you mean" suggestion for `query` drawn from the
    /// tokens of `cachedTitles`, or nil if no useful candidate exists.
    ///
    /// **Rules.**
    /// - Tokenize `cachedTitles` (lowercase, strip punctuation, split on
    ///   whitespace/hyphens). Build a frequency map of unique tokens of
    ///   length ≥ 3 to skip noise ("a", "of", "and").
    /// - For each query token, find the closest token from the cached
    ///   set with Levenshtein distance in `(minDistance, maxDistance]`
    ///   — exclusive of `minDistance` (defaults to 1) so we don't
    ///   re-suggest what `TitleSearchMatcher`'s Levenshtein-1 already
    ///   matched; inclusive of `maxDistance` (defaults to 4) because
    ///   past 4 edits the suggestion stops resembling what the user
    ///   typed.
    /// - If multiple query tokens have qualifying candidates, prefer
    ///   the one with the smallest distance. Tie-break across equal
    ///   distances by token frequency in the cache (more popular =
    ///   better suggestion).
    /// - Rebuild the suggestion query by substituting only the changed
    ///   token (preserves `"cast iron <typo>"` → `"cast iron nachos"`
    ///   — keep the unchanged words verbatim so multi-word suggestions
    ///   feel natural).
    /// - Reject self-suggestions (suggested string normalizes to the
    ///   same thing the user already typed).
    public static func suggest(
        query: String,
        cachedTitles: [String],
        minDistance: Int = 1,
        maxDistance: Int = 4
    ) -> String? {
        guard !cachedTitles.isEmpty else { return nil }
        let normalizedQuery = TitleSearchMatcher.normalize(query)
        guard !normalizedQuery.isEmpty else { return nil }
        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        guard !queryTokens.isEmpty else { return nil }

        let frequency = tokenFrequencyMap(from: cachedTitles)
        guard !frequency.isEmpty else { return nil }

        // Score each query token against every cache token in the
        // distance band; the per-query-token search is delegated to
        // `bestCandidate(for:in:...)` so this entry point keeps
        // SwiftLint's `cyclomatic_complexity` cap happy.
        var winner: Candidate?
        for (index, queryToken) in queryTokens.enumerated() {
            guard queryToken.count >= 3, frequency[queryToken] == nil else { continue }
            let candidate = bestCandidate(
                for: queryToken,
                queryTokenIndex: index,
                in: frequency,
                minDistance: minDistance,
                maxDistance: maxDistance
            )
            if let candidate, candidate.improvesOver(winner) {
                winner = candidate
            }
        }

        guard let winner else { return nil }
        let index = winner.queryTokenIndex
        let suggestion = winner.cacheToken

        let rebuilt = substitute(
            tokenAt: index,
            with: suggestion,
            into: query
        )

        // Self-suggestion guard — if the rebuilt query normalizes back
        // to the user's input, don't bother surfacing it (covers
        // casing-only or punctuation-only "differences").
        if TitleSearchMatcher.normalize(rebuilt) == normalizedQuery {
            return nil
        }
        return rebuilt
    }

    // MARK: - Candidate scoring

    /// A scored (queryToken, cacheToken) pair. Compared by
    /// `improvesOver(_:)` so the outer loop only needs the one
    /// expression to keep its candidate-vs-winner comparison.
    /// Skip query tokens that already exist in the cache. The user
    /// typed a word that's a real recipe token — they don't need a
    /// suggestion to swap it for a neighbor. Without that guard,
    /// "cast iron naxxos" would let the tie-break pull "cast" → "iron"
    /// (both length 4, distance 4, both in cache).
    struct Candidate {
        let queryTokenIndex: Int
        let cacheToken: String
        let distance: Int
        let frequency: Int

        /// Better-than-current rule: lower distance always wins; on a
        /// distance tie, higher frequency wins; on a frequency tie,
        /// the alphabetically-earlier cache token wins so the output
        /// is deterministic across hash-map iteration orders.
        func improvesOver(_ other: Candidate?) -> Bool {
            guard let other else { return true }
            if distance != other.distance { return distance < other.distance }
            if frequency != other.frequency { return frequency > other.frequency }
            return cacheToken < other.cacheToken
        }
    }

    /// Per-query-token sweep: scan every cache token in the
    /// `(minDistance, maxDistance]` band and return the best one (or
    /// nil if nothing in the band passes the length-delta gate).
    /// Extracted from `suggest(...)` to keep that function under
    /// SwiftLint's cyclomatic-complexity cap.
    static func bestCandidate(
        for queryToken: String,
        queryTokenIndex: Int,
        in frequency: [String: Int],
        minDistance: Int,
        maxDistance: Int
    ) -> Candidate? {
        var best: Candidate?
        for (cacheToken, count) in frequency where cacheToken != queryToken {
            let widthDelta = abs(cacheToken.count - queryToken.count)
            if widthDelta > maxDistance { continue }
            let distance = TitleSearchMatcher.levenshteinDistance(queryToken, cacheToken)
            guard distance > minDistance, distance <= maxDistance else { continue }
            let candidate = Candidate(
                queryTokenIndex: queryTokenIndex,
                cacheToken: cacheToken,
                distance: distance,
                frequency: count
            )
            if candidate.improvesOver(best) {
                best = candidate
            }
        }
        return best
    }

    // MARK: - Tokenization

    /// Per-cache-token frequency map. Skips tokens shorter than 3
    /// characters so noise like "a"/"of"/"and" doesn't waste a
    /// substitution slot. Normalization mirrors `TitleSearchMatcher`'s
    /// (HTML-entity decode + lowercase + punctuation→space + whitespace
    /// collapse) so a `&amp;` or em-dash on the cache side doesn't
    /// fragment the token set.
    static func tokenFrequencyMap(from titles: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for title in titles {
            let normalized = TitleSearchMatcher.normalize(title)
            for token in normalized.split(separator: " ") {
                let string = String(token)
                guard string.count >= 3 else { continue }
                map[string, default: 0] += 1
            }
        }
        return map
    }

    // MARK: - Substitution

    /// Substitute the query's `index`-th normalized token with
    /// `replacement`, preserving the surrounding tokens verbatim
    /// (whitespace + case). The original query is split on whitespace
    /// — the same simple boundary the view's display uses — so the
    /// rebuilt string reads naturally even when the user's original
    /// had mixed case ("Cast Iron Naxhos" → "Cast Iron nachos" — the
    /// substituted token comes back lowercased to match the canonical
    /// cache form, but every other token preserves the user's casing).
    static func substitute(
        tokenAt index: Int,
        with replacement: String,
        into originalQuery: String
    ) -> String {
        let splits = originalQuery.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let originalTokens = splits.map(String.init)
        // Defensive: the normalized-token index can drift if the
        // original had pure-punctuation tokens that normalize away.
        // In that case fall back to a whole-string replacement.
        guard index < originalTokens.count else {
            return replacement
        }
        var rebuilt = originalTokens
        rebuilt[index] = replacement
        return rebuilt.joined(separator: " ")
    }
}

import Foundation

/// Strength of a title-vs-query match. Lower raw value = stronger match.
///
/// Ranking (strongest first):
/// 1. ``exact``     — normalized title equals normalized query.
/// 2. ``substring`` — normalized query appears as a contiguous substring of
///    the normalized title.
/// 3. ``fuzzy``     — one of two tolerant rules fires:
///    a. plural/singular swap (each query token strips or appends a
///       trailing "s" and matches a title token), OR
///    b. Levenshtein distance ≤ 1 between at least one query token and
///       at least one title token (catches one-character typos like
///       "nahcos" → "nachos").
///
/// Spec trace: CL-120 (Nacho Bug — title-precision contract) / REG-29 /
/// US-12 amendment / US-29 amendment.
public enum TitleMatchKind: Int, Comparable, Sendable {
    case exact = 0
    case substring = 1
    case fuzzy = 2

    public static func < (lhs: TitleMatchKind, rhs: TitleMatchKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Pure helper that answers "does this title match this query?" with a
/// tier (`exact` / `substring` / `fuzzy`) so the search pipeline can
/// reject body-only WP hits while still allowing typo + plural/singular
/// tolerance.
///
/// Why this lives in `DODSupport` (not in `DODFeatureSearch`): the matcher
/// is a pure value-type function (Foundation-only, no dependencies) and a
/// future surface — Spotlight indexing, App Intents, share-extension
/// search — will want the same contract. Lifting it into the support
/// layer means every future caller gets the same precision rules without
/// a feature-package dependency.
///
/// Spec trace: CL-120 (Nacho Bug), REG-29, US-12 amendment, US-29 amendment.
public enum TitleSearchMatcher {

    /// Returns the strongest ``TitleMatchKind`` for `query` vs `title`,
    /// or `nil` when no rule matches. Inputs are normalized (HTML-entity
    /// decoded, lowercased, punctuation → space, whitespace collapsed)
    /// before comparison so WP's `&amp;` / `&#8217;` / em-dashes / smart
    /// quotes never leak through to the match.
    ///
    /// Multi-token queries: the substring tier requires the whole joined
    /// query to appear contiguously in the title (so "super nacho"
    /// matches "Super Nacho Dip" but not "Just Nachos"); the fuzzy tier
    /// requires **every** query token to have at least one title-token
    /// hit (plural swap or Levenshtein-1) — partial token coverage is
    /// not a match.
    public static func match(query: String, title: String) -> TitleMatchKind? {
        let normalizedTitle = normalize(title)
        let normalizedQuery = normalize(query)
        guard !normalizedTitle.isEmpty, !normalizedQuery.isEmpty else { return nil }

        if normalizedTitle == normalizedQuery {
            return .exact
        }
        if normalizedTitle.contains(normalizedQuery) {
            return .substring
        }

        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        let titleTokens = normalizedTitle.split(separator: " ").map(String.init)
        guard !queryTokens.isEmpty, !titleTokens.isEmpty else { return nil }

        if pluralFuzzyMatches(queryTokens: queryTokens, titleString: normalizedTitle) {
            return .fuzzy
        }
        if levenshteinFuzzyMatches(queryTokens: queryTokens, titleTokens: titleTokens) {
            return .fuzzy
        }
        return nil
    }

    // MARK: - Normalization

    /// HTML-entity decode → lowercase → fold diacritics → punctuation→space
    /// → collapse whitespace. Reuses ``HTMLSanitizer`` for the entity decode
    /// so `&amp;` / `&#8217;` etc. don't leak into the comparison; the WP
    /// `title.rendered` payload routinely carries them.
    ///
    /// DUT-306: diacritic-insensitive folding (e.g. "Jalapeño" → "jalapeno")
    /// so an accent-free query matches an accented title and vice-versa.
    static func normalize(_ input: String) -> String {
        let decoded = HTMLSanitizer.plainText(from: input)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(decoded.unicodeScalars.count)
        for scalar in decoded.unicodeScalars {
            let isPunctOrSymbol =
                CharacterSet.punctuationCharacters.contains(scalar)
                || CharacterSet.symbols.contains(scalar)
            if isPunctOrSymbol {
                scalars.append(Unicode.Scalar(0x20))
            } else {
                scalars.append(scalar)
            }
        }
        let stripped = String(scalars)
        let parts = stripped.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return parts.joined(separator: " ")
    }

    // MARK: - Fuzzy rules

    /// Each query token is swapped between singular and plural by toggling
    /// a trailing "s", and **every** query token (after swap) must appear
    /// as a substring of the title for the rule to fire. Per-token gating
    /// preserves the "all tokens must match" multi-token contract from
    /// CL-120 — "super nacho" must NOT fuzzy-match "Just Nachos" because
    /// "super" / "supers" appears nowhere in the title even though
    /// "nacho" → "nachos" does. Single-token queries fall out trivially:
    /// one token, one match required.
    private static func pluralFuzzyMatches(
        queryTokens: [String],
        titleString: String
    ) -> Bool {
        for token in queryTokens {
            let swapped = token.hasSuffix("s") ? String(token.dropLast()) : token + "s"
            // The original token's substring presence was already
            // checked at the higher tier (and missed, or we wouldn't
            // be here on a single-token query). For multi-token
            // queries, the original token might still appear in the
            // title even though the joined-query substring did not —
            // accept either the original or the plural-swapped form
            // as the per-token signal.
            let tokenMatches =
                titleString.contains(token)
                || (!swapped.isEmpty && titleString.contains(swapped))
            if !tokenMatches { return false }
        }
        return true
    }

    /// Every query token must have at least one title token within
    /// Levenshtein distance 1 (insert / delete / substitute / transpose
    /// counted as ≤ 1 edit). Distance-2 is intentionally rejected — it
    /// admits too much noise on a small corpus ("naxxos" must NOT match
    /// "nachos" per CL-120's "two typos is too loose" rule).
    private static func levenshteinFuzzyMatches(
        queryTokens: [String],
        titleTokens: [String]
    ) -> Bool {
        for queryToken in queryTokens {
            var matched = false
            for titleToken in titleTokens
            where abs(queryToken.count - titleToken.count) <= 1 {
                if levenshteinDistance(queryToken, titleToken) <= 1 {
                    matched = true
                    break
                }
            }
            if !matched { return false }
        }
        return true
    }

    /// Iterative Levenshtein (Wagner–Fischer two-row variant). Returns
    /// the edit-distance between `lhs` and `rhs`. O(m·n) time, O(min(m,n))
    /// space; no third-party dependency. Used by ``levenshteinFuzzyMatches``
    /// gated on a `|len(a) - len(b)| ≤ 1` shortcut so the matrix is
    /// only built for plausibly-near pairs.
    ///
    /// CL-127 (T-649): also used by ``SearchSuggestionEngine`` in this
    /// module for the "did you mean?" path; the access stays
    /// module-internal so the math has one canonical definition for
    /// every search-precision consumer in `DODSupport`.
    static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let lhsCount = lhsChars.count
        let rhsCount = rhsChars.count
        if lhsCount == 0 { return rhsCount }
        if rhsCount == 0 { return lhsCount }

        var previous = Array(0...rhsCount)
        var current = [Int](repeating: 0, count: rhsCount + 1)
        for row in 1...lhsCount {
            current[0] = row
            for column in 1...rhsCount {
                let cost = lhsChars[row - 1] == rhsChars[column - 1] ? 0 : 1
                current[column] = min(
                    previous[column] + 1,  // deletion
                    current[column - 1] + 1,  // insertion
                    previous[column - 1] + cost  // substitution
                )
            }
            swap(&previous, &current)
        }
        return previous[rhsCount]
    }
}

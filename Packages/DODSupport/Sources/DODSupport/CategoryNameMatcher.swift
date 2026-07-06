import DODDomain
import Foundation

/// Pure helper that answers "does this query name a known WP category?".
/// Returns the matched categories sorted by `count` descending, capped at
/// the top two so the calling pipeline can bound its parallel network
/// cost to at most two `?categories=<id>` REST fetches per typed query.
///
/// Why this is **additive** to ``TitleSearchMatcher`` (and not a fourth
/// tier inside it). T-642 / CL-120 / REG-29 established a strict title-
/// precision contract for the REST `?search=` candidate set — admitting
/// body-only hits regressed to the Nacho-Bug class. The recipes a user
/// is reaching for when they type a category name ("Dessert Recipes",
/// "Chicken and Poultry Recipes") are titled by their own dish names
/// (Apple Crumble, Cherry Cobbler) and never contain the category word
/// in their `title.rendered`. Folding category-name match into
/// `TitleSearchMatcher` would either weaken the title-precision contract
/// (and reopen the Nacho regression) or require the matcher to know about
/// WP categories (a layering violation — `TitleSearchMatcher` is a pure
/// string function). The clean factoring: `CategoryNameMatcher` is a
/// sibling helper, fired from a parallel pipeline path in
/// `SearchViewModel.performSearch()` that unions its results with the
/// title path; both rules stay independent and local.
///
/// Why it lives in `DODSupport` (mirrors `TitleSearchMatcher`'s placement).
/// Pure value-type function, Foundation-only, no feature-package or
/// network dependency. Future surfaces — Spotlight indexing, App Intents,
/// share-extension search — will want the same category-aware contract
/// without depending on `DODFeatureSearch`.
///
/// Spec trace: CL-121 (T-643 — category-match path), REG-30,
/// US-12 amendment / US-29 amendment / AC-12.1 amendment / AC-29.1 amendment.
public enum CategoryNameMatcher {

    /// Maximum number of categories returned. Bounds the calling
    /// pipeline's parallel network cost — every matched category becomes
    /// a `?categories=<id>&per_page=100` REST fetch, so two matches is the
    /// worst-case wire ceiling per typed query. The cap is exposed as a
    /// `static let` so future tasks (or tests fabricating > 2 matches) can
    /// reason about it directly.
    public static let maxMatches: Int = 2

    /// Minimum normalized-query length for the substring-of-topic rule
    /// to fire. Guards against generic short tokens (`"the"`, `"a"`,
    /// `"of"`) substring-matching the topic of an unrelated category
    /// and fanning out a `?categories=` fetch the user didn't intend.
    /// 4 chars is the smallest threshold that excludes the obvious junk
    /// while still accepting `"beef"` / `"side"` / `"chic"` substrings.
    static let substringOfTopicMinLength: Int = 4

    /// Single-token junk queries that would otherwise substring- or
    /// topic-match every category in the catalog. Rejected at the
    /// matcher entry point so the calling pipeline never sees a fan-out
    /// of N category fetches for a generic word.
    static let junkSingleTokens: Set<String> = ["recipe", "recipes"]

    /// Returns the categories whose name matches `query`, sorted by
    /// `count` desc and capped at ``maxMatches``. Empty array means
    /// "no category match" — the calling pipeline then falls back to
    /// title-match-only behavior (the T-642 / CL-120 / REG-29 path
    /// unchanged).
    ///
    /// Match rules (any of these fires):
    /// 1. Normalized query equals the full normalized category name.
    /// 2. Normalized query equals the category's "topic" (the name with
    ///    a trailing `" recipes"` stripped; falls back to the full name
    ///    if the suffix isn't present).
    /// 3. Normalized query is a substring of the topic AND the query is
    ///    at least ``substringOfTopicMinLength`` characters.
    /// 4. The topic is a substring of the normalized query AND the topic
    ///    is at least ``substringOfTopicMinLength`` characters (DUT-317:
    ///    same short-token floor as rule 3).
    ///
    /// Junk-query reject: if the normalized query is exactly one of the
    /// ``junkSingleTokens`` (single-token suffix-only `"recipe"` /
    /// `"recipes"`), the function returns `[]` without evaluating any
    /// category — preventing a fan-out of N fetches for a generic word.
    public static func match(
        query: String,
        in categories: [DODDomain.Category]
    ) -> [DODDomain.Category] {
        let normalizedQuery = TitleSearchMatcher.normalize(query)
        guard !normalizedQuery.isEmpty else { return [] }
        if Self.junkSingleTokens.contains(normalizedQuery) { return [] }

        var matched: [DODDomain.Category] = []
        for category in categories {
            let normalizedName = TitleSearchMatcher.normalize(category.name)
            guard !normalizedName.isEmpty else { continue }
            let topic = stripRecipesSuffix(normalizedName)
            if matches(query: normalizedQuery, name: normalizedName, topic: topic) {
                matched.append(category)
            }
        }
        return Array(matched.sorted { $0.count > $1.count }.prefix(Self.maxMatches))
    }

    // MARK: - Rule helpers

    /// Strip a trailing `" recipes"` token from `normalizedName`. If the
    /// name doesn't end with the suffix, return it unchanged — defensive
    /// for a future WP taxonomy that doesn't follow the convention. The
    /// suffix check is whole-word (preceded by a space and at end-of-
    /// string) so a category like `"Recipes"` alone returns `"recipes"`
    /// (the topic equals the name) rather than the empty string.
    static func stripRecipesSuffix(_ normalizedName: String) -> String {
        let suffix = " recipes"
        if normalizedName.hasSuffix(suffix), normalizedName.count > suffix.count {
            return String(normalizedName.dropLast(suffix.count))
        }
        return normalizedName
    }

    /// Apply rules 1-4 from the doc-comment. Pulled into a helper to
    /// keep ``match(query:in:)`` short and to make each rule independently
    /// readable.
    private static func matches(query: String, name: String, topic: String) -> Bool {
        if query == name { return true }
        if query == topic { return true }
        // DUT-664: gate rule 3 with the same whole-word containment as rule 4
        // (DUT-508). Raw `topic.contains(query)` false-positives when the query
        // is embedded in a larger word of the topic — e.g. query "read" inside
        // topic "bread". The query must appear as a standalone token in the
        // topic (`"beef"` in `"beef and broccoli"` still matches).
        if query.count >= Self.substringOfTopicMinLength, containsWholeWord(query, in: topic) {
            return true
        }
        // DUT-317: gate rule 4 on the same minimum-length floor as rule 3
        // so a short topic token (e.g. a 3-char category topic) can't
        // substring-match an unrelated query and fan out a fetch.
        // DUT-508: require whole-word containment — raw substring matching
        // false-positives when a short topic is embedded in a larger word
        // (topic "rice" inside query "licorice"). The topic must appear as a
        // standalone token in the query (a query token equal to the topic still
        // matches, e.g. "rice pilaf" → topic "rice").
        if topic.count >= Self.substringOfTopicMinLength, containsWholeWord(topic, in: query) {
            return true
        }
        return false
    }

    /// True when `topic` appears inside `query` bounded by word boundaries —
    /// i.e. it is not embedded in a larger alphanumeric run. Prevents the
    /// embedded-substring false match ("rice" inside "licorice") while still
    /// matching a real occurrence, including a multi-word topic phrase
    /// ("side dish" inside "easy side dish ideas") and a single query token
    /// ("rice" in "rice pilaf"). A character is a "boundary" when it isn't a
    /// letter or number, so spaces and edges qualify but adjacent letters do
    /// not.
    private static func containsWholeWord(_ topic: String, in query: String) -> Bool {
        var searchStart = query.startIndex
        while let range = query.range(of: topic, range: searchStart..<query.endIndex) {
            let leftIsBoundary: Bool
            if range.lowerBound == query.startIndex {
                leftIsBoundary = true
            } else {
                let before = query[query.index(before: range.lowerBound)]
                leftIsBoundary = !before.isLetter && !before.isNumber
            }
            let rightIsBoundary: Bool
            if range.upperBound == query.endIndex {
                rightIsBoundary = true
            } else {
                let after = query[range.upperBound]
                rightIsBoundary = !after.isLetter && !after.isNumber
            }
            if leftIsBoundary, rightIsBoundary { return true }
            searchStart = query.index(after: range.lowerBound)
        }
        return false
    }
}

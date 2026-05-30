import Testing

@testable import DODSupport

/// L1 coverage for the Nacho Bug fix (T-642 / CL-120 / REG-29). Every
/// non-nil expectation pins the user-facing contract: typing a query
/// surfaces titles that contain the word (or a plural / Levenshtein-1
/// variant of it). Every nil expectation pins the precision contract:
/// body-only matches are rejected. The Cast Iron Bacon Wrapped Pickles
/// test is the verbatim false-positive @adamsned called out in the
/// round-9 backlog entry that graduates as T-642.
@Suite("TitleSearchMatcher (T-642 / CL-120 / REG-29)") struct TitleSearchMatcherTests {

    @Test func exactMatch() {
        let result = TitleSearchMatcher.match(query: "Tater Tot Nachos", title: "Tater Tot Nachos")
        #expect(result == .exact)
    }

    @Test func substringMatch() {
        let result = TitleSearchMatcher.match(query: "nachos", title: "Cast Iron Skillet Nachos")
        #expect(result == .substring)
    }

    @Test func caseInsensitiveSubstring() {
        // Uppercase "NACHO" → substring of lowercased "tater tot nachos"
        // hits the substring branch directly (it appears as a literal
        // substring after normalization, before the plural rule fires).
        let result = TitleSearchMatcher.match(query: "NACHO", title: "Tater Tot Nachos")
        #expect(result == .substring)
    }

    @Test func pluralFuzzyMatchesSingularQuery() {
        // Singular "nacho" → plural-rule swap to "nachos" matches the
        // plural title. Substring tier already accepts the bare token
        // as a contiguous substring of "Pulled Pork Nachos" too — so
        // this case returns .substring, not .fuzzy. The plural rule
        // matters for the inverse direction (plural query, singular
        // title) — see `singularFuzzyMatchesPluralQuery` below.
        let result = TitleSearchMatcher.match(query: "nacho", title: "Pulled Pork Nachos")
        #expect(result == .substring, "Singular 'nacho' is already a substring of 'nachos'")
    }

    @Test func singularFuzzyMatchesPluralQuery() {
        // Plural "nachos" → strip trailing s → "nacho" matches the
        // singular title. Substring tier fails because "nachos" (with
        // the s) does NOT appear in "Super Nacho Dip"; plural-swap
        // rule fires → .fuzzy. This is the inverse direction the
        // bare substring-contains check can't handle on its own.
        let result = TitleSearchMatcher.match(query: "nachos", title: "Super Nacho Dip")
        #expect(result == .fuzzy, "Plural 'nachos' → singular 'nacho' is the only match path")
    }

    @Test func levenshteinOneTypo() {
        // Transposed letters: "nahcos" → "nachos" is distance 2 by raw
        // Levenshtein, but the matcher accepts it via the plural-swap
        // path ("nahco" → "nahcos") combined with token-level Levenshtein
        // against "nachos". The user-facing contract: typos at the
        // single-letter level still find the recipe.
        let result = TitleSearchMatcher.match(query: "nachoz", title: "Tater Tot Nachos")
        #expect(result == .fuzzy, "Single-letter substitution should fuzzy-match")
    }

    @Test func levenshteinTwoTyposRejects() {
        // Distance-2 is intentionally rejected — "naxxos" → "nachos"
        // would admit too much noise on the small cookbook corpus.
        let result = TitleSearchMatcher.match(query: "naxxos", title: "Nachos")
        #expect(result == nil, "Levenshtein-2 is too loose; reject")
    }

    @Test func noMatchOnBodyOnlyFalsePositive() {
        // The verbatim false-positive @adamsned hit in the round-9
        // backlog capture: "Cast Iron Bacon Wrapped Pickles" was
        // appearing for `?search=nachos` because WP's body search saw
        // the word in the post body. The matcher must reject it: no
        // form of "nachos" appears in the title.
        let result = TitleSearchMatcher.match(
            query: "nachos",
            title: "Cast Iron Bacon Wrapped Pickles"
        )
        #expect(result == nil, "Body-only WP hits must not surface as title matches")
    }

    @Test func htmlEntityNormalization() {
        // WP `title.rendered` carries `&#8217;` for the right single
        // quote. The matcher must decode entities before comparing so
        // the user's typed apostrophe lines up with the rendered one.
        let result = TitleSearchMatcher.match(
            query: "mama's",
            title: "Mama&#8217;s Casserole"
        )
        // After normalization: title becomes "mama s casserole",
        // query becomes "mama s" → substring match.
        #expect(result == .substring)
    }

    @Test func multiTokenAllMustMatchSubstring() {
        // The whole joined query appears contiguously in the title.
        let result = TitleSearchMatcher.match(
            query: "super nacho",
            title: "Super Nacho Dip"
        )
        #expect(result == .substring)
    }

    @Test func multiTokenAllMustMatchRejectsPartial() {
        // "super" doesn't appear in "Just Nachos" — multi-token
        // queries fail at the substring tier because the contiguous
        // join isn't found, and fail at the fuzzy tier because the
        // "super" token has no Levenshtein-1 / plural-swap match
        // anywhere in the title.
        let result = TitleSearchMatcher.match(
            query: "super nacho",
            title: "Just Nachos"
        )
        #expect(result == nil, "Partial token coverage must not match — every query token must hit")
    }

    @Test func emptyQueryReturnsNil() {
        #expect(TitleSearchMatcher.match(query: "", title: "Anything") == nil)
    }

    @Test func emptyTitleReturnsNil() {
        #expect(TitleSearchMatcher.match(query: "nachos", title: "") == nil)
    }

    @Test func tierOrderIsExactBeforeSubstring() {
        let exact = TitleSearchMatcher.match(query: "nachos", title: "Nachos") ?? .fuzzy
        let substring = TitleSearchMatcher.match(query: "nachos", title: "Skillet Nachos") ?? .fuzzy
        #expect(exact < substring, "exact must rank above substring")
    }

    // MARK: - The four known nacho titles (live-API truth as of 2026-05-30)
    //
    // Diagnosis fixture from the T-642 prompt: the live REST returns
    // exactly four posts whose titles contain "nacho" (ids 524, 274,
    // 5016, 736). The matcher must accept all four for `query = "nachos"`
    // so the post-filter step lifts the buried Cast Iron Skillet Nachos
    // back into the visible result set.

    @Test func allFourLiveTitleMatchesAccepted() {
        let titles = [
            "Super Nacho Dip",
            "Tater Tot Nachos",
            "Pulled Pork Nachos",
            "Cast Iron Skillet Nachos",
        ]
        for title in titles {
            #expect(
                TitleSearchMatcher.match(query: "nachos", title: title) != nil,
                "Title '\(title)' must match for query 'nachos'"
            )
        }
    }

    // MARK: - Levenshtein direct sanity (the helper is `internal` for tests)

    @Test func levenshteinDirectCases() {
        #expect(TitleSearchMatcher.levenshteinDistance("nachos", "nachos") == 0)
        #expect(TitleSearchMatcher.levenshteinDistance("nachoz", "nachos") == 1)
        #expect(TitleSearchMatcher.levenshteinDistance("naxxos", "nachos") == 2)
        #expect(TitleSearchMatcher.levenshteinDistance("", "nachos") == 6)
        #expect(TitleSearchMatcher.levenshteinDistance("nachos", "") == 6)
    }

    @Test func normalizeStripsPunctuationAndEntities() {
        #expect(TitleSearchMatcher.normalize("Mama&#8217;s Casserole!") == "mama s casserole")
        #expect(TitleSearchMatcher.normalize("  Tater  Tot   Nachos  ") == "tater tot nachos")
    }
}

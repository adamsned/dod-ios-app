import Testing

@testable import DODSupport

/// L1 coverage for the T-649 / CL-127 "did you mean?" suggestion engine.
/// Each expectation pins a user-facing contract from CL-127's rule list:
/// the `(1, 4]` Levenshtein band, the multi-word substitution rule, the
/// self-suggestion guard, the frequency tie-break, the case-insensitive
/// tokenization, and the empty-cache fallthrough.
@Suite("SearchSuggestionEngine (T-649 / CL-127)")
struct SearchSuggestionEngineTests {

    // MARK: - Distance band

    @Test func query_with_two_letter_typo_returns_match() {
        // "naxxos" → "nachos" is distance 2 (positions 2,3 differ).
        // Distance 2 is INSIDE the (1, 4] band so the engine surfaces
        // it; this is the exact "post-T-642 strict filter has no
        // recourse" case CL-127 is built to soften.
        let suggestion = SearchSuggestionEngine.suggest(
            query: "naxxos",
            cachedTitles: ["Cast Iron Skillet Nachos", "Super Nacho Dip"]
        )
        #expect(suggestion == "nachos")
    }

    @Test func query_with_three_letter_typo_returns_match() {
        // "naxxod" → "nachos" is distance 3 (positions 2,3,5 differ).
        // Distance 3 still INSIDE (1, 4] so the suggestion stands.
        let suggestion = SearchSuggestionEngine.suggest(
            query: "naxxod",
            cachedTitles: ["Cast Iron Skillet Nachos"]
        )
        #expect(suggestion == "nachos")
    }

    @Test func query_at_max_distance_boundary_rejected() {
        // "totally" → "nachos" is distance 7 — past the (1, 4] cap.
        // Engine must NOT surface a far-distance neighbor; the suggestion
        // would stop resembling what the user typed.
        let suggestion = SearchSuggestionEngine.suggest(
            query: "totally",
            cachedTitles: ["Cast Iron Skillet Nachos"]
        )
        #expect(suggestion == nil)
    }

    @Test func query_at_min_distance_boundary_rejected() {
        // "nachoz" → "nachos" is distance 1 — TitleSearchMatcher's fuzzy
        // tier already absorbs distance-1, so re-suggesting it would be
        // tautological. The lower bound of (1, 4] is exclusive of 1.
        let suggestion = SearchSuggestionEngine.suggest(
            query: "nachoz",
            cachedTitles: ["Cast Iron Skillet Nachos"]
        )
        #expect(suggestion == nil, "Distance-1 is owned by TitleSearchMatcher fuzzy")
    }

    // MARK: - Self-suggestion guard

    @Test func query_already_matches_returns_nil() {
        // "nachos" exactly matches the cache token "nachos" (after
        // normalization). The engine must NOT suggest the user search
        // for the thing they already searched for.
        let suggestion = SearchSuggestionEngine.suggest(
            query: "nachos",
            cachedTitles: ["Cast Iron Skillet Nachos"]
        )
        #expect(suggestion == nil)
    }

    @Test func case_only_difference_returns_nil() {
        // "NACHOS" normalizes to the same token "nachos" the cache has.
        // The normalize-equivalent self-suggestion guard rejects it.
        let suggestion = SearchSuggestionEngine.suggest(
            query: "NACHOS",
            cachedTitles: ["Cast Iron Skillet Nachos"]
        )
        #expect(suggestion == nil, "Case-only delta is the self-suggestion guard's job")
    }

    // MARK: - Empty / degenerate inputs

    @Test func empty_cache_returns_nil() {
        let suggestion = SearchSuggestionEngine.suggest(
            query: "naxxos",
            cachedTitles: []
        )
        #expect(suggestion == nil)
    }

    @Test func empty_query_returns_nil() {
        let suggestion = SearchSuggestionEngine.suggest(
            query: "",
            cachedTitles: ["Cast Iron Skillet Nachos"]
        )
        #expect(suggestion == nil)
    }

    @Test func short_query_token_skipped() {
        // Tokens shorter than 3 characters are skipped — a 1- or 2-char
        // query token is too short to compute a useful Levenshtein
        // distance against (e.g. "ab" is distance 6 from "nachos",
        // distance 4 from "the", etc., and surfaces nonsense).
        let suggestion = SearchSuggestionEngine.suggest(
            query: "ab",
            cachedTitles: ["Cast Iron Skillet Nachos"]
        )
        #expect(suggestion == nil)
    }

    // MARK: - Tokenization

    @Test func case_insensitive_tokenization() {
        // Cache titles with uppercase letters must still token-match
        // a lowercase typo query. The cache token is the canonical
        // lowercase form regardless of source casing.
        let suggestion = SearchSuggestionEngine.suggest(
            query: "naxxos",
            cachedTitles: ["NACHOS Recipe"]
        )
        #expect(suggestion == "nachos")
    }

    @Test func punctuation_stripped_from_cache_tokens() {
        // The cache title's "Nachos!" punctuation must normalize away
        // so the token is "nachos", not "nachos!".
        let suggestion = SearchSuggestionEngine.suggest(
            query: "naxxos",
            cachedTitles: ["Nachos!"]
        )
        #expect(suggestion == "nachos")
    }

    // MARK: - Tie-break by frequency

    @Test func tie_break_by_frequency() {
        // Both "nachos" and "tortos" are distance 2 from "naxxos" in
        // this contrived fixture. The cache contains "nachos" three
        // times and "tortos" once, so frequency tie-break picks
        // "nachos".
        let titles = [
            "Cast Iron Skillet Nachos",
            "Super Nachos",
            "Loaded Nachos",
            "Strange Tortos",
        ]
        let suggestion = SearchSuggestionEngine.suggest(
            query: "naxxos",
            cachedTitles: titles
        )
        #expect(suggestion == "nachos", "Higher-frequency cache token wins on distance tie")
    }

    // MARK: - Multi-word substitution

    @Test func multi_word_query_substitutes_only_typo_token() {
        // "cast iron naxxos" must become "cast iron nachos" — only the
        // typo token swaps; the leading "cast iron" preserves verbatim
        // (case + spacing). This is the load-bearing rule for the
        // multi-word UX: rewriting the entire phrase would read as the
        // engine "guessing" rather than gently correcting one word.
        let titles = ["Cast Iron Skillet Nachos"]
        let suggestion = SearchSuggestionEngine.suggest(
            query: "cast iron naxxos",
            cachedTitles: titles
        )
        #expect(suggestion == "cast iron nachos")
    }

    @Test func multi_word_query_preserves_user_casing_on_unchanged_tokens() {
        // "Cast Iron Naxhos" (user-cased) must become "Cast Iron nachos"
        // — the substituted token comes back lowercased (canonical
        // cache form), but the unchanged tokens preserve the user's
        // original capitalization so the second render doesn't read
        // as a styling shift.
        let titles = ["Cast Iron Skillet Nachos"]
        let suggestion = SearchSuggestionEngine.suggest(
            query: "Cast Iron Naxxos",
            cachedTitles: titles
        )
        #expect(suggestion == "Cast Iron nachos")
    }

    @Test func hyphenatedQueryKeepsAllTokenPositions() {
        // DUT-366: with a hyphen the raw whitespace-split ("chiken-pot", "pie" → 2)
        // and the normalized split (chiken, pot, pie → 3) diverge. The winner index
        // points into the normalized array, so indexing the RAW split with it used
        // to substitute the wrong word or drop a token (collapse to 2 words). The
        // fix rebuilds from the normalized tokens, so the suggestion keeps all three
        // positions regardless of which token the engine picks as the typo.
        let titles = ["Chicken Pot Pie"]
        let suggestion = SearchSuggestionEngine.suggest(
            query: "chiken-pot pie",
            cachedTitles: titles
        )
        #expect(suggestion?.split(separator: " ").count == 3)
    }
}

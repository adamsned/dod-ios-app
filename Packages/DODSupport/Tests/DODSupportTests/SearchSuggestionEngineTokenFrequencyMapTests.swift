import Testing

@testable import DODSupport

/// Direct unit test coverage for `SearchSuggestionEngine.tokenFrequencyMap(from:)`,
/// the tokenization and frequency-aggregation helper that builds the cache map
/// for "did you mean?" suggestions.
///
/// Each test isolates the tokenization contract: normalization mirrors
/// `TitleSearchMatcher.normalize(_:)` (HTML-entity decode + lowercase + diacritic-fold
/// + punctuation→space + whitespace-collapse), and tokens shorter than 3 characters
/// are skipped (to exclude noise like "a", "of", "and").
@Suite("SearchSuggestionEngine.tokenFrequencyMap(from:)")
struct TokenFrequencyMapTests {

    // MARK: - Token length boundary

    @Test
    func tokenBelowThreeCharactersExcluded() {
        // Tokens < 3 characters must be skipped to avoid noise.
        // "A of Pie" normalizes to "a of pie"; only "pie" is >= 3 chars.
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["A of Pie"]
        )
        #expect(result == ["pie": 1])
        #expect(result["a"] == nil, "Single-char 'a' must be skipped")
        #expect(result["of"] == nil, "Two-char 'of' must be skipped")
    }

    @Test
    func tokenExactlyThreeCharactersIncluded() {
        // Tokens of exactly 3 characters must be included (>= 3 is inclusive).
        // "The Dip Pie" normalizes to "the dip pie"; all three are exactly 3 chars.
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["The Dip Pie"]
        )
        #expect(result == ["the": 1, "dip": 1, "pie": 1])
    }

    // MARK: - HTML entity decoding

    @Test
    func htmlEntityDecodedCorrectly() {
        // `&amp;` entity must decode to `&`, which is then treated as punctuation
        // and converted to a space-separator (not appearing as a token itself).
        // "Mac &amp; Cheese" → "mac & cheese" → "mac cheese" (after punct→space)
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["Mac &amp; Cheese"]
        )
        #expect(result == ["mac": 1, "cheese": 1])
        #expect(result["&"] == nil, "Punctuation-converted & must not appear as token")
        #expect(result["amp"] == nil, "Entity name 'amp' must not appear")
    }

    @Test
    func htmlNumericEntityDecoded() {
        // Numeric HTML entities are decoded by HTMLSanitizer. An apostrophe
        // is punctuation and converts to a space. "It's Pie" → "it s pie" →
        // split and rejoin → "it s pie"; "it" and "s" are both < 3, so only
        // "pie" survives.
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["It's Pie"]
        )
        #expect(result.count == 1, "Should have exactly one token >= 3 chars")
        #expect(result["pie"] == 1, "'Pie' is the only token >= 3 chars")
    }

    // MARK: - Frequency aggregation

    @Test
    func frequencyAggregatedAcrossTitles() {
        // The same token appearing in multiple titles must have its count
        // incremented in the map. "chicken" appears in both titles.
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: [
                "Chicken Stew",
                "Roasted Chicken",
                "Chicken Pot Pie",
            ]
        )
        #expect(result["chicken"] == 3, "Token 'chicken' appears in all three titles")
        #expect(result["stew"] == 1)
        #expect(result["roasted"] == 1)
        #expect(result["pot"] == 1)
        #expect(result["pie"] == 1)
    }

    @Test
    func frequencyAccuracyMultipleSharedTokens() {
        // Multiple titles with overlapping token sets must correctly aggregate.
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: [
                "Cast Iron Skillet",
                "Cast Iron Nachos",
                "Skillet Nachos",
            ]
        )
        #expect(result["cast"] == 2, "'cast' in first two titles")
        #expect(result["iron"] == 2, "'iron' in first two titles")
        #expect(result["skillet"] == 2, "'skillet' in first and third")
        #expect(result["nachos"] == 2, "'nachos' in second and third")
    }

    // MARK: - Case insensitivity

    @Test
    func caseInsensitiveTokenization() {
        // Different casings of the same word must collapse into ONE map entry
        // with a combined count. "NACHOS" and "nachos" and "Nachos" all normalize
        // to "nachos".
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: [
                "NACHOS Recipe",
                "nachos dip",
                "Nachos Appetizer",
            ]
        )
        #expect(result["nachos"] == 3, "Case-insensitive 'nachos' aggregates to 3")
        #expect(result.count == 4, "Should have 4 unique tokens (nachos, recipe, dip, appetizer)")
    }

    // MARK: - Punctuation and whitespace handling

    @Test
    func punctuationStrippedFromTokens() {
        // Trailing punctuation (and other punctuation chars) must be converted
        // to spaces and the result re-split. "Nachos!" normalizes to "nachos"
        // (the `!` is punctuation → space → token is just "nachos").
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["Nachos!"]
        )
        #expect(result == ["nachos": 1])
        #expect(result.count == 1, "Exactly one token; punctuation is gone")
    }

    @Test
    func multiplePunctuationCharactersConverted() {
        // Multiple punctuation chars must all convert to spaces, and the
        // resulting whitespace collapse must leave one canonical token.
        // "Nachos... the best!" → punctuation→space → "nachos   the best " →
        // collapse → "nachos the best".
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["Nachos... the Best!"]
        )
        #expect(result["nachos"] == 1)
        #expect(result["the"] == 1)
        #expect(result["best"] == 1)
    }

    @Test
    func whitespaceContinuityPreserved() {
        // Multiple spaces and newlines must collapse to single spaces, and
        // split on both space and newline characters.
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["Nachos   The\nBest"]
        )
        #expect(result["nachos"] == 1)
        #expect(result["the"] == 1)
        #expect(result["best"] == 1)
    }

    // MARK: - Diacritics

    @Test
    func diacriticsNormalizedAway() {
        // Accented characters (diacritics) must fold to unaccented equivalents
        // via `diacriticInsensitive` folding. "Jalapeño" → "jalapeno".
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["Jalapeño Poppers"]
        )
        #expect(result["jalapeno"] == 1, "Accent on ñ must fold to n")
        #expect(result["poppers"] == 1)
    }

    // MARK: - Empty input

    @Test
    func emptyTitlesArrayReturnsEmptyMap() {
        // Passing an empty titles array must return an empty map.
        let result = SearchSuggestionEngine.tokenFrequencyMap(from: [])
        #expect(result.isEmpty)
    }

    @Test
    func titleWithOnlyShortTokensReturnsEmpty() {
        // A title whose tokens all fall below 3 characters (e.g. "A of It")
        // must contribute nothing to the map.
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["A of It"]
        )
        #expect(result.isEmpty, "All tokens < 3 chars; map is empty")
    }

    @Test
    func mixedTitlesOneContributesNothing() {
        // One title contributes valid tokens, another has only short tokens.
        // The second title's tokens are skipped; the map reflects only the first.
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: [
                "Cast Iron Nachos",
                "A of It",
            ]
        )
        #expect(result.count == 3)
        #expect(result["cast"] == 1)
        #expect(result["iron"] == 1)
        #expect(result["nachos"] == 1)
    }

    // MARK: - Edge cases

    @Test
    func emptyStringTitleContributesNothing() {
        // An empty string, after normalization, is empty and yields no tokens.
        let result = SearchSuggestionEngine.tokenFrequencyMap(from: [""])
        #expect(result.isEmpty)
    }

    @Test
    func whitespaceOnlyTitleContributesNothing() {
        // A title with only whitespace/newlines normalizes to empty and
        // yields no tokens.
        let result = SearchSuggestionEngine.tokenFrequencyMap(from: ["   \n  \t  "])
        #expect(result.isEmpty)
    }

    @Test
    func symbolsReplacedWithSpace() {
        // Mathematical and currency symbols (e.g. `$`, `€`, `±`) are classified
        // as symbol characters and must convert to spaces, not survive as tokens.
        // "Cost $100 Pan" → "cost 100 pan" (the $ is converted to space).
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["Cost $100 Pan"]
        )
        #expect(result["cost"] == 1)
        #expect(result["100"] == 1, "'100' is exactly 3 chars, so it's included")
        #expect(result["pan"] == 1)
        #expect(result.count == 3, "$ symbol is stripped; '100' is >= 3 chars")
    }

    @Test
    func parenthesesAndBracketsRemoved() {
        // Parentheses, brackets, and similar punctuation must all convert to
        // spaces. "Recipe (Classic)" → "recipe classic".
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["Recipe (Classic)"]
        )
        #expect(result["recipe"] == 1)
        #expect(result["classic"] == 1)
    }

    @Test
    func hyphenTreatedAsPunctuation() {
        // Hyphens are punctuation and convert to spaces.
        // "Chicken-Pot Pie" → "chicken pot pie".
        let result = SearchSuggestionEngine.tokenFrequencyMap(
            from: ["Chicken-Pot Pie"]
        )
        #expect(result == ["chicken": 1, "pot": 1, "pie": 1])
    }

    // MARK: - Comprehensive integration

    @Test
    func realWorldRecipeTitleFlow() {
        // A realistic multi-title corpus with overlapping tokens, mixed case,
        // punctuation, and short words. Verify the entire pipeline works end-to-end.
        let titles = [
            "Dutch Oven Chicken & Rice",
            "Cast Iron Skillet Nachos!",
            "Slow Cooker (Dutch Oven) Stew",
            "NACHOS: The Perfect Appetizer",
        ]
        let result = SearchSuggestionEngine.tokenFrequencyMap(from: titles)

        // Check for expected aggregations and filters
        #expect(result["dutch"] == 2, "Dutch appears in titles 0 and 2")
        #expect(result["oven"] == 2, "Oven appears in titles 0 and 2")
        #expect(result["nachos"] == 2, "Nachos (case-insensitive) appears in titles 1 and 3")
        #expect(result["chicken"] == 1)
        #expect(result["cast"] == 1)
        #expect(result["iron"] == 1)
        #expect(result["skillet"] == 1)
        #expect(result["slow"] == 1)
        #expect(result["cooker"] == 1)
        #expect(result["stew"] == 1)
        #expect(result["rice"] == 1)
        #expect(result["the"] == 1)
        #expect(result["perfect"] == 1)
        #expect(result["appetizer"] == 1)

        // Verify short tokens are excluded
        #expect(result["&"] == nil, "Symbol converted to space, not a token")
        #expect(result["a"] == nil, "Single-char 'a' excluded")

        // Verify the map has exactly the expected tokens
        #expect(result.count == 14, "14 unique valid tokens across all titles")
    }
}

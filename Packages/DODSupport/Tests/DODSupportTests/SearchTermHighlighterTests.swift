import Foundation
import Testing

@testable import DODSupport

/// L1 unit tests for ``SearchTermHighlighter`` (DUT-10). The highlighter returns
/// the character-offset ranges of query terms inside a result title so the UI
/// can emphasize them; matching is per-token, case + diacritic insensitive,
/// against the original (un-normalized) title.
@Suite("SearchTermHighlighter") struct SearchTermHighlighterTests {

    /// Map the returned offset ranges back to the substrings they cover, for
    /// readable assertions.
    private func matchedSubstrings(_ text: String, _ query: String) -> [String] {
        SearchTermHighlighter.matchedRanges(in: text, query: query).map { range in
            let lower = text.index(text.startIndex, offsetBy: range.lowerBound)
            let upper = text.index(text.startIndex, offsetBy: range.upperBound)
            return String(text[lower..<upper])
        }
    }

    @Test func highlightsExactSubstring() {
        #expect(matchedSubstrings("Cast Iron Skillet Nachos", "nachos") == ["Nachos"])
    }

    @Test func matchingIsCaseInsensitive() {
        #expect(matchedSubstrings("NACHOS Supreme", "nachos") == ["NACHOS"])
        #expect(matchedSubstrings("Nachos Supreme", "NACHOS") == ["Nachos"])
    }

    @Test func matchingIsDiacriticInsensitive() {
        // ASCII query lights up the accented title, and vice-versa.
        #expect(matchedSubstrings("Spicy Jalapeño Poppers", "jalapeno") == ["Jalapeño"])
        #expect(matchedSubstrings("Spicy Jalapeno Poppers", "jalapeño") == ["Jalapeno"])
    }

    @Test func highlightsEachQueryToken() {
        #expect(matchedSubstrings("Garlic Butter Skillet Corn", "garlic butter") == ["Garlic", "Butter"])
    }

    @Test func highlightsEveryOccurrence() {
        #expect(matchedSubstrings("Corn and Corn Bread", "corn") == ["Corn", "Corn"])
    }

    @Test func resultsAreSortedByPosition() {
        // Tokens given out of order still return ranges in document order.
        #expect(matchedSubstrings("Butter Garlic Rolls", "garlic butter") == ["Butter", "Garlic"])
    }

    @Test func mergesOverlappingTokenMatches() {
        // "nacho" (0..<5) and "nachos" (0..<6) collapse to a single 0..<6 span.
        let ranges = SearchTermHighlighter.matchedRanges(in: "Nachos", query: "nacho nachos")
        #expect(ranges == [0..<6])
    }

    @Test func mergesAdjacentMatches() {
        // "corn" (0..<4) and "bread" (4..<9) abut at offset 4, so they coalesce
        // into one contiguous "Cornbread" span rather than two touching ones.
        #expect(matchedSubstrings("Cornbread", "corn bread") == ["Cornbread"])
    }

    @Test func returnsEmptyWhenNothingMatches() {
        #expect(SearchTermHighlighter.matchedRanges(in: "Cast Iron Nachos", query: "pizza").isEmpty)
    }

    @Test func returnsEmptyForBlankQuery() {
        #expect(SearchTermHighlighter.matchedRanges(in: "Nachos", query: "").isEmpty)
        #expect(SearchTermHighlighter.matchedRanges(in: "Nachos", query: "   ").isEmpty)
    }

    @Test func skipsSubThresholdTokens() {
        // Single-character tokens are noise and are ignored.
        #expect(SearchTermHighlighter.matchedRanges(in: "A Bowl of Chili", query: "a o").isEmpty)
        // ...but a real >= 2-char token in the same query still matches.
        #expect(matchedSubstrings("A Bowl of Chili", "a chili") == ["Chili"])
    }

    @Test func returnsEmptyForEmptyText() {
        #expect(SearchTermHighlighter.matchedRanges(in: "", query: "nachos").isEmpty)
    }

    @Test func offsetsAddressGraphemesNotScalars() {
        // The accented title has an emoji before the match; offsets must count
        // Characters (grapheme clusters) so they map onto AttributedString.
        let text = "🌶️ Jalapeño Bites"
        let subs = matchedSubstrings(text, "bites")
        #expect(subs == ["Bites"])
    }

    // MARK: - DUT-668 NFC normalization

    /// A DECOMPOSED accent in the title (`n` + combining `~` for `ñ`) is not
    /// folded by `.diacriticInsensitive` alone. Precomposing both sides to NFC
    /// first realigns them so the accented word highlights. The offsets are
    /// against the precomposed text, so index into that form to read them back.
    @Test func decomposedAccentInTitleHighlights() {
        // "Jalapen\u{0303}o" — decomposed ñ (n + COMBINING TILDE).
        let decomposedTitle = "Jalape\u{006E}\u{0303}o Poppers"
        let ranges = SearchTermHighlighter.matchedRanges(in: decomposedTitle, query: "jalapeno")
        #expect(ranges.count == 1)
        let normalized = decomposedTitle.precomposedStringWithCanonicalMapping
        guard let range = ranges.first else {
            Issue.record("expected one matched range")
            return
        }
        let lower = normalized.index(normalized.startIndex, offsetBy: range.lowerBound)
        let upper = normalized.index(normalized.startIndex, offsetBy: range.upperBound)
        #expect(String(normalized[lower..<upper]) == "Jalapeño")
    }
}

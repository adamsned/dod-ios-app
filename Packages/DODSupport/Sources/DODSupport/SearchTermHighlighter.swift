import Foundation

/// Computes the character-offset ranges of search-query terms inside a result
/// string (e.g. a recipe title) so the UI can emphasize them -- the "feels
/// native" match highlight users expect from Spotlight / Mail / Contacts search
/// (DUT-10).
///
/// Matching is per whitespace-delimited query token, case- AND diacritic-
/// insensitive (so "jalapeno" highlights "Jalapeno" / "Jalapeño" and "NACHOS"
/// highlights "Nachos"), run against the ORIGINAL string so the returned
/// offsets line up with the un-normalized title the card actually renders.
/// Tokens shorter than ``minimumTokenLength`` are skipped to avoid lighting up
/// noise words. Overlapping / adjacent matches are merged; the result is sorted
/// by start offset.
///
/// Offsets are Character distances from the start, which map directly onto an
/// `AttributedString` built from the same text via `index(_:offsetByCharacters:)`.
/// Pure and view-agnostic: the visual treatment (color / weight) is applied by
/// the renderer, keeping this layer free of any design-system dependency.
public enum SearchTermHighlighter {

    /// Query tokens shorter than this are ignored -- a 1-character token would
    /// light up nearly every word. Two keeps short-but-real terms ("pb", "ox")
    /// while dropping stray single letters.
    public static let minimumTokenLength = 2

    /// Character-offset ranges in `text` covered by any query token. Empty when
    /// `query` is blank, carries only sub-threshold tokens, or nothing matches.
    public static func matchedRanges(in text: String, query: String) -> [Range<Int>] {
        let tokens =
            query
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { $0.count >= minimumTokenLength }
        guard !tokens.isEmpty, !text.isEmpty else { return [] }

        var ranges: [Range<Int>] = []
        for token in tokens {
            var searchStart = text.startIndex
            while let found = text.range(
                of: token,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex
            ) {
                let lower = text.distance(from: text.startIndex, to: found.lowerBound)
                let upper = text.distance(from: text.startIndex, to: found.upperBound)
                ranges.append(lower..<upper)
                // Always advance at least one character so a degenerate match
                // can't spin the loop forever.
                searchStart =
                    found.upperBound > found.lowerBound
                    ? found.upperBound : text.index(after: found.lowerBound)
                if searchStart >= text.endIndex { break }
            }
        }
        return mergeOverlapping(ranges)
    }

    /// Sort by start offset and coalesce overlapping / touching ranges into one.
    private static func mergeOverlapping(_ ranges: [Range<Int>]) -> [Range<Int>] {
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [Range<Int>] = []
        for range in sorted {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}

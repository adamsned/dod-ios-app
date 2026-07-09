import Foundation

extension WPDTO {

    /// DUT-645: WordPress appends a "read more" affordance to `excerpt.rendered`
    /// — a trailing `<a class="more-link">…</a>` (and/or a bare "Continue
    /// reading …" run) whose inner text ("Continue reading …", `[…]`) survives
    /// tag-stripping and leaks into list-row excerpts. Strip the trailing
    /// more-link element and any leftover "Continue reading" trailer here, on
    /// the excerpt specifically, before the shared `HTMLSanitizer` runs.
    static func strippingMoreLink(_ excerptHTML: String) -> String {
        // Cheap early-out: the vast majority of excerpts carry neither
        // affordance, so skip both ICU passes entirely for them. Case-insensitive
        // to match the regexes below — both require the literal "more-link" /
        // "Continue reading" run (case-insensitively), so any excerpt lacking
        // both substrings provably matches neither regex, making this skip exact.
        guard
            excerptHTML.range(of: "more-link", options: .caseInsensitive) != nil
                || excerptHTML.range(of: "Continue reading", options: .caseInsensitive) != nil
        else { return excerptHTML }

        var result = excerptHTML
        // Strip the more-link element even when trailing block-close tags
        // (`</p>`, `</div>`) follow it — WP nests the anchor inside the excerpt
        // paragraph, so `</a>` is rarely the literal end of the string.
        if let regex = moreLinkAnchorRegex, let range = firstMatchRange(regex, in: result) {
            result.removeSubrange(range)
        }
        // Belt-and-suspenders: a leftover bare "Continue reading …" / "[…]"
        // trailer (some themes emit it outside the anchor) also gets trimmed,
        // tolerating trailing close tags. The ellipsis may arrive as the literal
        // `…` character or as an un-decoded entity (`&hellip;` / `&#8230;`), so
        // match all three forms — otherwise a `[&hellip;]` bracket is left
        // dangling once "Continue reading" is stripped (DUT-688).
        if let regex = continueReadingTrailerRegex, let range = firstMatchRange(regex, in: result) {
            result.removeSubrange(range)
        }
        return result
    }

    /// First-match range of `regex` over the whole of `string`, or nil.
    /// Equivalent to `string.range(of:options:.regularExpression)` but reuses a
    /// pre-compiled `NSRegularExpression` instead of recompiling per call.
    private static func firstMatchRange(
        _ regex: NSRegularExpression,
        in string: String
    ) -> Range<String.Index>? {
        let full = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, range: full) else { return nil }
        return Range(match.range, in: string)
    }

    /// DUT — hoisted, pre-compiled versions of the two more-link patterns.
    /// Foundation does NOT cache `.range(of:options:.regularExpression)` — each
    /// call built a fresh `NSRegularExpression`, so a 20-post REST page compiled
    /// ~40 regexes. Options replicate the original `.range(of:)` behavior exactly:
    /// `.caseInsensitive` (was passed alongside `.regularExpression`), `$`
    /// anchors to end-of-input (no `.anchorsMatchLines`), and the inline `(?s)`
    /// in the first pattern keeps dotall for its `.*?` span.
    private static let moreLinkAnchorRegex = try? NSRegularExpression(
        pattern:
            #"(?s)<a\b[^>]*class\s*=\s*["'][^"']*\bmore-link\b[^"']*["'][^>]*>.*?</a>\s*(?:</[a-zA-Z][^>]*>\s*)*$"#,
        options: [.caseInsensitive]
    )

    private static let continueReadingTrailerRegex: NSRegularExpression? = {
        let ellipsis = #"(?:…|&hellip;|&#8230;)"#
        let trailer = #"\s*(?:\[\s*\#(ellipsis)\s*\]\s*)?Continue reading\s*\#(ellipsis)?\s*(?:</[a-zA-Z][^>]*>\s*)*$"#
        return try? NSRegularExpression(pattern: trailer, options: [.caseInsensitive])
    }()
}

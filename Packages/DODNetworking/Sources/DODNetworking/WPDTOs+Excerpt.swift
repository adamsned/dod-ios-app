import Foundation

extension WPDTO {

    /// DUT-645: WordPress appends a "read more" affordance to `excerpt.rendered`
    /// — a trailing `<a class="more-link">…</a>` (and/or a bare "Continue
    /// reading …" run) whose inner text ("Continue reading …", `[…]`) survives
    /// tag-stripping and leaks into list-row excerpts. Strip the trailing
    /// more-link element and any leftover "Continue reading" trailer here, on
    /// the excerpt specifically, before the shared `HTMLSanitizer` runs.
    static func strippingMoreLink(_ excerptHTML: String) -> String {
        var result = excerptHTML
        // Strip the more-link element even when trailing block-close tags
        // (`</p>`, `</div>`) follow it — WP nests the anchor inside the excerpt
        // paragraph, so `</a>` is rarely the literal end of the string.
        if let range = result.range(
            of: #"(?s)<a\b[^>]*class\s*=\s*["'][^"']*\bmore-link\b[^"']*["'][^>]*>.*?</a>\s*(?:</[a-zA-Z][^>]*>\s*)*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            result.removeSubrange(range)
        }
        // Belt-and-suspenders: a leftover bare "Continue reading …" / "[…]"
        // trailer (some themes emit it outside the anchor) also gets trimmed,
        // tolerating trailing close tags.
        if let range = result.range(
            of: #"\s*(?:\[\s*…\s*\]\s*)?Continue reading\s*…?\s*(?:</[a-zA-Z][^>]*>\s*)*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            result.removeSubrange(range)
        }
        return result
    }
}

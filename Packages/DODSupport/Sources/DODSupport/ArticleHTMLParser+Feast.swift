import Foundation

// MARK: - Feast SEO-button stripping (DUT-21)

/// Feast-theme "SEO action button" stripping for ``ArticleHTMLParser``, split
/// into its own file so the core parser stays under the 400-line `file_length`
/// cap. The Feast plugin injects a "Summarize and Save…" cluster (an AI-prompt
/// launcher + a "Trusted Google Source" link) into every post body; in the
/// native render the buttons are non-functional and the heading renders as an
/// orphan, so the whole cluster is dropped at parse time. The recipe / category
/// index grids and jump-to navigation Feast blocks are real round-up content
/// and are intentionally NOT touched.
extension ArticleHTMLParser {

    /// Feast-theme "SEO action button" `<div>` class tokens. These render as a
    /// non-functional / orphaned cluster in the native article view — an AI
    /// prompt launcher ("Summarize and Save…": ChatGPT / Google AI / Perplexity
    /// / Grok) and a "Trusted Google Source" link — none of which belong in-app.
    /// The OTHER Feast blocks in a round-up body (recipe / category index grids,
    /// jump-to navigation) are real content and are intentionally NOT listed.
    static let feastSEOButtonClasses = ["feast-ai-buttons-block", "feast-trusted-google-source"]

    /// Strip the Feast SEO action-button blocks (``feastSEOButtonClasses``) plus
    /// the "Summarize and Save…" heading that introduces them, so neither leaks
    /// into the native render (DUT-21). External / recipe links inside ordinary
    /// prose are untouched — they keep their `href` and route via the article
    /// `openURL` handler (recipe → in-app deep link, else the browser).
    static func removeFeastSEOBlocks(from html: String) -> String {
        var output = removeSummarizeAndSaveHeading(from: html)
        for token in feastSEOButtonClasses {
            output = removeDivBlock(withClassToken: token, from: output)
        }
        return output
    }

    /// Remove every `<div …>…</div>` whose `class` contains `token`, balancing
    /// nested `<div>`s (the Feast buttons nest `wp-block-buttons` /
    /// `wp-block-button`) to find each element's true close (DUT-21).
    static func removeDivBlock(withClassToken token: String, from html: String) -> String {
        var output = html
        var fromIndex = output.startIndex
        while let open = output.range(of: "<div", options: .caseInsensitive, range: fromIndex..<output.endIndex) {
            guard let openEnd = output.range(of: ">", range: open.upperBound..<output.endIndex) else { break }
            let attributes = output[open.upperBound..<openEnd.lowerBound]
            let body = openEnd.upperBound
            guard
                ArticleBodyExtractor.hasClassToken(attributes: attributes, token: token),
                let inner = ArticleBodyExtractor.sliceUntilMatchingClose(
                    in: output,
                    openTag: "<div",
                    closeTag: "</div>",
                    bodyStart: body
                ),
                let close = output.range(
                    of: "</div>",
                    options: .caseInsensitive,
                    range: output.index(body, offsetBy: inner.count)..<output.endIndex
                )
            else {
                fromIndex = body  // not a match (or unbalanced) — advance past this `<div`
                continue
            }
            output.removeSubrange(open.lowerBound..<close.upperBound)
            fromIndex = output.startIndex  // the mutation invalidated indices — rescan from start
        }
        return output
    }

    /// The WP-generated anchor-id signature for the Feast "Summarize and Save…"
    /// heading. The WP heading-anchor convention prefixes the slug with `h-`, so
    /// the id is `h-summarize-and-save-the-recipe` / `…-the-method`; the token is
    /// the stable head of that slug across both visible-text variants.
    static let feastSummarizeAnchorToken = "summarize-and-save"

    /// Remove the Feast "Summarize and Save…" heading. The WP-generated anchor
    /// id contains `summarize-and-save` (the visible text varies: "…the Recipe"
    /// / "…the Method"), so it is the stable signature. Without this the heading
    /// would render as an orphan once the AI block beneath it is gone (DUT-21).
    ///
    /// DUT-316: match the token specifically inside the parsed `id="…"` attribute
    /// value (not anywhere in the raw opening-tag attribute string), so a heading
    /// that merely carries the token in a `class` / `data-*` / other attribute —
    /// real round-up content — is NOT over-matched and dropped.
    static func removeSummarizeAndSaveHeading(from html: String) -> String {
        var output = html
        var fromIndex = output.startIndex
        while let open = output.range(of: "<h", options: .caseInsensitive, range: fromIndex..<output.endIndex) {
            // Require `<h1>`…`<h6>`: the character after "<h" must be a digit 1–6.
            guard
                open.upperBound < output.endIndex,
                let level = output[open.upperBound].wholeNumberValue,
                (1...6).contains(level),
                let openEnd = output.range(of: ">", range: open.upperBound..<output.endIndex)
            else {
                fromIndex = open.upperBound
                continue
            }
            let attributes = output[open.upperBound..<openEnd.lowerBound]
            guard
                idAttributeContainsFeastAnchorToken(attributes: attributes),
                let close = output.range(
                    of: "</h\(level)>",
                    options: .caseInsensitive,
                    range: openEnd.upperBound..<output.endIndex
                )
            else {
                fromIndex = openEnd.upperBound
                continue
            }
            output.removeSubrange(open.lowerBound..<close.upperBound)
            fromIndex = output.startIndex
        }
        return output
    }

    /// Whether the parsed `id="…"` attribute value carries the Feast
    /// ``feastSummarizeAnchorToken`` as a complete hyphen-delimited slug segment
    /// (the WP heading anchor is `h-summarize-and-save-the-recipe` / `…-the-method`,
    /// where the token sits between the `h-` prefix and the trailing variant). Only
    /// the `id` value is inspected — the token appearing inside a `class` /
    /// `data-*` / other attribute does NOT match, and a token that is merely a
    /// substring of an unrelated id segment (e.g. `presummarize-and-saver`) is
    /// rejected — so genuine content headings survive (DUT-316).
    static func idAttributeContainsFeastAnchorToken<S: StringProtocol>(attributes: S) -> Bool {
        guard let id = idAttributeValue(attributes: attributes) else { return false }
        let token = feastSummarizeAnchorToken
        let lowered = id.lowercased()
        // Split the id on hyphens and look for a run of consecutive segments that
        // spells out the (hyphen-delimited) token — i.e. the token appears as a
        // whole slug fragment, not glued inside a larger segment.
        let idSegments = lowered.split(separator: "-", omittingEmptySubsequences: false)
        let tokenSegments = token.split(separator: "-", omittingEmptySubsequences: false)
        guard idSegments.count >= tokenSegments.count else { return false }
        for start in 0...(idSegments.count - tokenSegments.count)
        where Array(idSegments[start..<start + tokenSegments.count]) == Array(tokenSegments) {
            return true
        }
        return false
    }

    /// Extract the value of the `id` attribute from an opening-tag attribute
    /// string (e.g. `class="…" id='…'`). Tolerates single / double / no quotes
    /// and the `id` attribute appearing in any position; returns nil when absent.
    /// Mirrors the quote handling of ``ArticleBodyExtractor/hasClassToken``
    /// (DUT-316).
    static func idAttributeValue<S: StringProtocol>(attributes: S) -> String? {
        let attrString = String(attributes)
        var searchStart = attrString.startIndex
        // Scan for an `id` attribute name: a standalone `id` token (preceded by a
        // boundary) followed by optional whitespace then `=`. This skips
        // substrings like `data-id` / `grid` / `valid` where `id` is not the name.
        while let idRange = attrString.range(
            of: "id",
            options: .caseInsensitive,
            range: searchStart..<attrString.endIndex
        ) {
            searchStart = idRange.upperBound
            if idRange.lowerBound != attrString.startIndex {
                let before = attrString[attrString.index(before: idRange.lowerBound)]
                guard before.isWhitespace else { continue }
            }
            var index = idRange.upperBound
            while index < attrString.endIndex, attrString[index].isWhitespace {
                index = attrString.index(after: index)
            }
            guard index < attrString.endIndex, attrString[index] == "=" else { continue }
            index = attrString.index(after: index)
            while index < attrString.endIndex, attrString[index].isWhitespace {
                index = attrString.index(after: index)
            }
            guard index < attrString.endIndex else { return nil }
            let quote = attrString[index]
            guard quote == "\"" || quote == "'" else {
                // Unquoted value — read up to the next whitespace.
                let tail = attrString[index...]
                return tail.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
            }
            let valueStart = attrString.index(after: index)
            guard let valueEnd = attrString[valueStart...].firstIndex(of: quote) else { return nil }
            return String(attrString[valueStart..<valueEnd])
        }
        return nil
    }
}

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

    /// Remove the Feast "Summarize and Save…" heading. The WP-generated anchor
    /// id contains `summarize-and-save` (the visible text varies: "…the Recipe"
    /// / "…the Method"), so it is the stable signature. Without this the heading
    /// would render as an orphan once the AI block beneath it is gone (DUT-21).
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
                attributes.range(of: "summarize-and-save", options: .caseInsensitive) != nil,
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
}

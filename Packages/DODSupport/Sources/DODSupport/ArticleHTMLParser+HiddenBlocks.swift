import Foundation

// MARK: - Hidden-block stripping (DUT-918b)

/// Pinterest share-card and `display:none` `<div>` stripping for
/// ``ArticleHTMLParser``, split into its own file to keep the core parser
/// under the 400-line `file_length` cap.
///
/// WordPress sites running the DPSP / Grow Social plugin inject a hidden `<div>`
/// around Pinterest collage images:
/// ```html
/// <div class="dpsp-post-pinterest-image-hidden" style="display: none;">
///   <img data-pin-media="…-Collage.jpg" …>
/// </div>
/// ```
/// The website hides these with `display:none`, but ``ArticleHTMLParser``
/// scans every `<img>` it finds regardless of a hidden parent, so the branded
/// collages rendered in-app.  ``removeHiddenBlocks(from:)`` strips these before
/// ``scanBlocks`` runs.
extension ArticleHTMLParser {

    /// CSS class tokens whose presence marks a `<div>` as a hidden social
    /// share-card that must be stripped before the block scan.
    static let hiddenDivClassTokens: [String] = ["dpsp-post-pinterest-image-hidden"]

    /// Remove any `<div>` from `html` that is marked hidden by EITHER:
    ///
    ///   - a `class` token listed in ``hiddenDivClassTokens`` (e.g. the
    ///     DPSP / Grow Social Pinterest share-card wrapper), **or**
    ///   - an inline `style` attribute whose `display` property is `none`
    ///     (whitespace- and case-tolerant: `display:none`, `display: none`,
    ///     `display : none`).
    ///
    /// The matching close tag is located via depth-balanced `<div>` tracking —
    /// the same ``ArticleBodyExtractor/sliceUntilMatchingClose`` that Feast
    /// block removal uses — so the ENTIRE hidden div (including nested
    /// `<img>` / `<figure>` children) is removed as a unit.  Visible content
    /// that follows the hidden div is left intact.
    static func removeHiddenBlocks(from html: String) -> String {
        var output = html
        var fromIndex = output.startIndex
        while let open = output.range(of: "<div", options: .caseInsensitive, range: fromIndex..<output.endIndex) {
            guard let openEnd = output.range(of: ">", range: open.upperBound..<output.endIndex) else { break }
            let attributes = output[open.upperBound..<openEnd.lowerBound]
            let body = openEnd.upperBound
            let isHidden =
                hiddenDivClassTokens.contains {
                    ArticleBodyExtractor.hasClassToken(attributes: attributes, token: $0)
                } || styleHasDisplayNone(attributes)
            guard
                isHidden,
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
            fromIndex = output.startIndex  // mutation invalidated indices — rescan from start
        }
        return output
    }

    /// Whether an opening-tag attribute string has a `style` attribute whose
    /// `display` property is `none` (whitespace- and case-tolerant).
    ///
    /// The `style` value is parsed via ``ArticleHTMLParser/attributeValue(_:in:)``
    /// so the check never fires on other attributes that happen to contain the
    /// substring `display:none`.  Each semicolon-delimited CSS property is
    /// stripped of all whitespace before comparison, so all of these match:
    ///
    /// ```
    /// style="display:none"
    /// style="display: none"
    /// style="display : none"
    /// style="color:red; display : none ; font-size:12px"
    /// ```
    static func styleHasDisplayNone<S: StringProtocol>(_ attributes: S) -> Bool {
        let styleValue = ArticleHTMLParser.attributeValue("style", in: attributes)
        guard !styleValue.isEmpty else { return false }
        for property in styleValue.components(separatedBy: ";") {
            let compact = property.filter { !$0.isWhitespace }.lowercased()
            if compact == "display:none" {
                return true
            }
        }
        return false
    }
}

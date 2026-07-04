import Foundation

/// DUT-544: instructions-region scoping for the "How to Make" numbered-step
/// fallback, split out of ``WPRMRecipeCardParser`` so the main type stays under
/// SwiftLint's `type_body_length` / `file_length` caps.
extension WPRMRecipeCardParser {

    /// Heading-text fragments that mark the start of a post's instructions /
    /// "How to Make" region. Matched case-insensitively against the plain-text
    /// of each `<h2>`; the first hit anchors the region the step scan is
    /// confined to (DUT-544).
    static let instructionsHeadingMarkers = [
        "how to make",
        "how to cook",
        "how to prepare",
        "instructions",
        "directions",
        "step-by-step",
    ]

    /// DUT-544 fallback (scopes the DUT-538 fallback): collect step text from
    /// the `<ol class="…is-style-circle-number-list…">` lists that live inside
    /// the post's instructions / "How to Make" region ONLY — never page-wide.
    ///
    /// **Why the scope (DUT-544).** DUT-538 scanned every
    /// `is-style-circle-number-list` `<ol>` on the page, so an unrelated
    /// author-styled numbered list elsewhere in the body (a "Tips",
    /// "Substitutions", or "Variations" list that happens to use the same
    /// Gutenberg block style) was injected into the steps. We now slice the page
    /// from the first `<h2>` whose text names an instructions region (see
    /// ``instructionsHeadingMarkers``) to the next `<h2>` boundary and scan only
    /// that slice. WPRM renders the "How to Make" steps as one such `<ol>` per
    /// step (each holding a single `<li>`), so flattening the `<li>` rows across
    /// the matching lists inside the region yields the ordered steps.
    ///
    /// When NO instructions heading is present, we return no steps rather than
    /// falling back to a page-wide scan — an un-anchored numbered `<ol>` can't
    /// be trusted to be recipe steps (that is exactly the pollution DUT-544
    /// fixes). The 7 Can Soup shape HAS the "How to Make Dutch Oven 7 Can Soup"
    /// `<h2>`, so its four steps are recovered unchanged.
    static func parseNumberedStepList(in page: String) -> [String] {
        guard let region = instructionsRegion(in: page) else { return [] }
        return collectElementInners(in: region, tag: "ol", classToken: numberedStepListToken)
            .flatMap { listInner in
                collectElementTexts(
                    in: listInner,
                    tag: "li",
                    classToken: nil,
                    transform: HTMLSanitizer.plainText(from:)
                )
            }
    }

    /// Slice the post's instructions region: from the first `<h2>` whose
    /// plain-text contains one of ``instructionsHeadingMarkers`` to the next
    /// `<h2>` (or end of page). Returns nil when no instructions heading is
    /// found. DUT-544.
    static func instructionsRegion(in page: String) -> String? {
        var cursor = page.startIndex
        while cursor < page.endIndex {
            guard
                let openStart = page.range(of: "<h2", options: .caseInsensitive, range: cursor..<page.endIndex)
            else {
                return nil
            }
            guard let openEnd = page.range(of: ">", range: openStart.upperBound..<page.endIndex) else {
                return nil
            }
            guard
                let inner = ArticleBodyExtractor.sliceUntilMatchingClose(
                    in: page,
                    openTag: "<h2",
                    closeTag: "</h2>",
                    bodyStart: openEnd.upperBound
                )
            else {
                cursor = openEnd.upperBound
                continue
            }
            let headingText = HTMLSanitizer.plainText(from: inner).lowercased()
            if instructionsHeadingMarkers.contains(where: headingText.contains) {
                // Region runs from just after this heading's close to the next
                // `<h2>` (exclusive), or the end of the page.
                let closeStart = page.index(openEnd.upperBound, offsetBy: inner.count)
                let regionStart =
                    page.range(of: "</h2>", range: closeStart..<page.endIndex)?.upperBound
                    ?? closeStart
                let regionEnd =
                    page.range(of: "<h2", options: .caseInsensitive, range: regionStart..<page.endIndex)?
                    .lowerBound ?? page.endIndex
                return String(page[regionStart..<regionEnd])
            }
            cursor = page.index(openEnd.upperBound, offsetBy: inner.count)
            if let closeRange = page.range(of: "</h2>", range: cursor..<page.endIndex) {
                cursor = closeRange.upperBound
            }
        }
        return nil
    }
}

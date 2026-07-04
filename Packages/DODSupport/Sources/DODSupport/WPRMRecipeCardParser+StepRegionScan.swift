import Foundation

/// DUT-554: the low-level heading scan behind ``WPRMRecipeCardParser``'s
/// instructions-region slice, split into its own file so both it and
/// ``WPRMRecipeCardParser+StepRegion`` stay under SwiftLint's
/// `file_length` / `type_body_length` caps.
extension WPRMRecipeCardParser {

    /// Slice the post's instructions region: from the first `<h2>` OR `<h3>`
    /// whose plain-text contains one of ``instructionsHeadingMarkers`` to the
    /// next heading of the SAME level (or the end of the page). Returns nil when
    /// no instructions heading is found.
    ///
    /// DUT-544 scanned only `<h2>`; DUT-554 also scans `<h3>` (WPRM/Gutenberg
    /// posts frequently put the steps sub-heading at `<h3>`). The region ends at
    /// the next heading of the matched heading's own level so an `<h3>`
    /// steps-heading region isn't cut short by an unrelated intervening `<h3>` of
    /// a different level — mirroring the original next-`<h2>` boundary.
    static func instructionsRegion(in page: String) -> String? {
        for tag in instructionsHeadingTags {
            if let region = instructionsRegion(in: page, headingTag: tag) {
                return region
            }
        }
        return nil
    }

    /// Scan `page` for the first `<headingTag>` whose plain-text matches an
    /// instructions marker, returning the slice from just after that heading to
    /// the next `<headingTag>` (or end of page). Nil when none matches.
    static func instructionsRegion(in page: String, headingTag tag: String) -> String? {
        let openMarker = "<\(tag)"
        let closeMarker = "</\(tag)>"
        var cursor = page.startIndex
        while cursor < page.endIndex {
            guard
                let openStart = page.range(of: openMarker, options: .caseInsensitive, range: cursor..<page.endIndex)
            else {
                return nil
            }
            guard let openEnd = page.range(of: ">", range: openStart.upperBound..<page.endIndex) else {
                return nil
            }
            guard
                let inner = ArticleBodyExtractor.sliceUntilMatchingClose(
                    in: page,
                    openTag: openMarker,
                    closeTag: closeMarker,
                    bodyStart: openEnd.upperBound
                )
            else {
                cursor = openEnd.upperBound
                continue
            }
            let headingText = HTMLSanitizer.plainText(from: inner).lowercased()
            if instructionsHeadingMarkers.contains(where: headingText.contains) {
                return regionSlice(
                    in: page,
                    afterInner: inner,
                    headingBodyStart: openEnd.upperBound,
                    closeMarker: closeMarker,
                    openMarker: openMarker
                )
            }
            cursor = page.index(openEnd.upperBound, offsetBy: inner.count)
            if let closeRange = page.range(of: closeMarker, range: cursor..<page.endIndex) {
                cursor = closeRange.upperBound
            }
        }
        return nil
    }

    /// Given a matched heading (its inner body + the index just after its opening
    /// tag), return the region running from just after the heading's close to the
    /// next `<headingTag>` opener (exclusive), or the end of the page.
    static func regionSlice(
        in page: String,
        afterInner inner: String,
        headingBodyStart: String.Index,
        closeMarker: String,
        openMarker: String
    ) -> String {
        let closeStart = page.index(headingBodyStart, offsetBy: inner.count)
        let regionStart =
            page.range(of: closeMarker, range: closeStart..<page.endIndex)?.upperBound
            ?? closeStart
        let regionEnd =
            page.range(of: openMarker, options: .caseInsensitive, range: regionStart..<page.endIndex)?
            .lowerBound ?? page.endIndex
        return String(page[regionStart..<regionEnd])
    }
}

import Foundation

// MARK: - Helper Functions

extension WPRMRecipeCardParser {

    /// Collect the raw (untransformed) inner body of every `<tag …>…</tag>` in
    /// `html` whose `class=` contains `classToken`, depth-tracking `<tag>`
    /// nesting. Order-preserving. Used to gather the `<ol>` step lists before
    /// their `<li>` rows are extracted.
    static func collectElementInners(in html: String, tag: String, classToken: String) -> [String] {
        var results: [String] = []
        var cursor = html.startIndex
        let openMarker = "<\(tag)"
        let closeMarker = "</\(tag)>"
        while cursor < html.endIndex {
            guard
                let openStart = html.range(of: openMarker, options: .caseInsensitive, range: cursor..<html.endIndex)
            else {
                break
            }
            guard let openEnd = html.range(of: ">", range: openStart.upperBound..<html.endIndex) else {
                break
            }
            let attributes = html[openStart.upperBound..<openEnd.lowerBound]
            guard ArticleBodyExtractor.hasClassToken(attributes: attributes, token: classToken) else {
                cursor = openEnd.upperBound
                continue
            }
            guard
                let inner = ArticleBodyExtractor.sliceUntilMatchingClose(
                    in: html,
                    openTag: openMarker,
                    closeTag: closeMarker,
                    bodyStart: openEnd.upperBound
                )
            else {
                cursor = openEnd.upperBound
                continue
            }
            results.append(inner)
            cursor = html.index(openEnd.upperBound, offsetBy: inner.count)
            if let closeRange = html.range(of: closeMarker, range: cursor..<html.endIndex) {
                cursor = closeRange.upperBound
            }
        }
        return results
    }

    /// Return the inner body of the first `<tag …>…</tag>` in `html` whose
    /// `class=` contains `classToken`, or nil when none is present.
    static func firstElementInner(in html: String, tag: String, classToken: String) -> String? {
        var cursor = html.startIndex
        let openMarker = "<\(tag)"
        while cursor < html.endIndex {
            guard
                let openStart = html.range(of: openMarker, options: .caseInsensitive, range: cursor..<html.endIndex)
            else {
                return nil
            }
            guard let openEnd = html.range(of: ">", range: openStart.upperBound..<html.endIndex) else {
                return nil
            }
            let attributes = html[openStart.upperBound..<openEnd.lowerBound]
            if ArticleBodyExtractor.hasClassToken(attributes: attributes, token: classToken) {
                return ArticleBodyExtractor.sliceUntilMatchingClose(
                    in: html,
                    openTag: openMarker,
                    closeTag: "</\(tag)>",
                    bodyStart: openEnd.upperBound
                )
            }
            cursor = openEnd.upperBound
        }
        return nil
    }
}

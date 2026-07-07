import Foundation

/// DUT-655 — list + blockquote block builders, factored out of
/// ``ArticleHTMLParser`` to keep that file under the 400-line cap.
extension ArticleHTMLParser {

    // MARK: - Lists

    /// Build a `.list` by inline-parsing each top-level `<li>…</li>`, or nil
    /// when empty.
    ///
    /// DUT-655: an `<li>` may itself contain a nested `<ul>`/`<ol>` (each with
    /// its own `<li>` children). The old first-`</li>` slice stopped at the
    /// FIRST nested `</li>`, truncating the outer item's text and re-scanning
    /// the nested items as siblings. We now depth-track `<li>` nesting to find
    /// each top-level item's matching close (see ``sliceMatchingLI``), and the
    /// item text folds any nested-list `<li>` text inline (the inline scanner
    /// ignores `<ul>`/`<ol>`/`<li>` tags, keeping their prose) so a nested list
    /// reads as part of its parent item rather than collapsing the list.
    static func listBlock<S: StringProtocol>(inner: S, ordered: Bool) -> ArticleBlock?
    where S.Index == String.Index {
        var items: [AttributedString] = []
        var cursor = inner.startIndex
        while let open = inner.range(of: "<li", options: .caseInsensitive, range: cursor..<inner.endIndex) {
            guard let openEnd = inner.range(of: ">", range: open.upperBound..<inner.endIndex) else { break }
            let (liInner, next) = sliceMatchingLI(from: openEnd.upperBound, in: inner)
            let text = inlineAttributedString(from: liInner)
            if !text.runs.isEmpty { items.append(text) }
            cursor = next
        }
        return items.isEmpty ? nil : .list(ordered: ordered, items: items)
    }

    /// Slice one `<li>` body from `bodyStart` to its DEPTH-MATCHED `</li>`,
    /// returning the inner substring + the cursor just past the close. Unlike
    /// ``sliceSimpleClose``, this counts nested `<li>` opens so a nested
    /// `<ul>`/`<ol>`'s `<li>` children don't prematurely close the outer item
    /// (DUT-655). Falls back to end-of-input on an unterminated item.
    static func sliceMatchingLI<S: StringProtocol>(
        from bodyStart: S.Index,
        in html: S
    ) -> (S.SubSequence, S.Index) where S.Index == String.Index {
        var depth = 1
        var scan = bodyStart
        while scan < html.endIndex {
            guard let mark = html.range(of: "<", range: scan..<html.endIndex) else { break }
            guard let markEnd = html.range(of: ">", range: mark.upperBound..<html.endIndex) else { break }
            let tagBody = html[mark.upperBound..<markEnd.lowerBound]
            let name = tagName(of: tagBody)
            if name == "li" {
                depth += 1
            } else if name == "/li" {
                depth -= 1
                if depth == 0 {
                    return (html[bodyStart..<mark.lowerBound], markEnd.upperBound)
                }
            }
            scan = markEnd.upperBound
        }
        return (html[bodyStart..<html.endIndex], html.endIndex)
    }

    // MARK: - Blockquote

    /// Split a `<blockquote>` body into one `.paragraph` per inner `<p>`
    /// child (DUT-655: a multi-paragraph pull-quote previously collapsed into
    /// a single run-on paragraph). When the blockquote carries no `<p>`
    /// children, fall back to one paragraph over its whole inline body.
    static func blockquoteBlocks<S: StringProtocol>(inner: S) -> [ArticleBlock]
    where S.Index == String.Index {
        var paragraphs: [ArticleBlock] = []
        var cursor = inner.startIndex
        while let open = inner.range(of: "<p", options: .caseInsensitive, range: cursor..<inner.endIndex) {
            // Guard against matching `<pre`/`<param` etc. — the char after
            // `<p` must end the tag name (whitespace or `>`).
            let afterP = open.upperBound
            let isParagraphTag = afterP == inner.endIndex || inner[afterP].isWhitespace || inner[afterP] == ">"
            guard isParagraphTag else {
                cursor = open.upperBound
                continue
            }
            guard let openEnd = inner.range(of: ">", range: open.upperBound..<inner.endIndex) else { break }
            let (pInner, next) = sliceSimpleClose(name: "p", from: openEnd.upperBound, in: inner)
            let text = inlineAttributedString(from: pInner)
            if !text.runs.isEmpty { paragraphs.append(.paragraph(text)) }
            cursor = next
        }
        if !paragraphs.isEmpty { return paragraphs }
        let text = inlineAttributedString(from: inner)
        return text.runs.isEmpty ? [] : [.paragraph(text)]
    }
}

import Foundation

/// Native HTML → ``ArticleBlock`` parser for WordPress article bodies.
///
/// Block-level scan over the sanitized `entry-content`, emitting blocks in
/// document order. Not a general-purpose HTML parser — handles the narrow,
/// well-formed Gutenberg shape WP produces, robust to attribute re-ordering and
/// irregular whitespace. Shares scanning helpers with ``ArticleBodyExtractor``.
public enum ArticleHTMLParser {
    /// Parse a WordPress post page into article blocks in document order.
    /// Returns `[]` when nothing renderable is found; blank blocks are skipped.
    ///
    /// - Parameters:
    ///   - html: the full rendered HTML page (or any fragment).
    ///   - baseURL: DUT-582 — page canonical URL to resolve protocol-/root-
    ///     relative image sources to absolute `http(s)`. Defaults `nil` (compat).
    public static func parse(html: String, baseURL: URL? = nil) -> [ArticleBlock] {
        // DUT-389/DUT-437: strip comments BEFORE the entry-content extraction —
        // a comment carrying `<div`/`</div>` corrupts the slice boundary's
        // depth tracking. The stripper is `<script>`/`<style>`-opaque (DUT-437).
        let stripped = HTMLSanitizer.strippingComments(html)
        // Scope to the WP body wrapper when present; else scan the whole input.
        var content = ArticleBodyExtractor.extractEntryContentSlice(in: stripped) ?? stripped
        // Drop blocks that never carry renderable prose, content and all.
        for tag in ["script", "style", "noscript", "svg"] {
            content = removeBlock(tag: tag, from: content)
        }
        // Strip the Feast-theme "SEO action button" cluster (DUT-21) — see
        // `removeFeastSEOBlocks`. Runs after the svg removal so the Trusted-
        // Source block's inline icon is already gone before the div walk.
        content = removeFeastSEOBlocks(from: content)
        return scanBlocks(content, baseURL: baseURL)
    }
}

// MARK: - Block scan

extension ArticleHTMLParser {

    /// Container tags whose nesting is depth-tracked to find the matching close.
    private static let depthTrackedContainers = ["figure", "ul", "ol", "blockquote"]

    /// Walk `html` emitting one ``ArticleBlock`` per recognized block-level tag.
    private static func scanBlocks(_ html: String, baseURL: URL?) -> [ArticleBlock] {
        var blocks: [ArticleBlock] = []
        var cursor = html.startIndex
        while cursor < html.endIndex {
            guard let open = html.range(of: "<", range: cursor..<html.endIndex) else { break }
            guard let close = html.range(of: ">", range: open.upperBound..<html.endIndex) else { break }
            let tagBody = html[open.upperBound..<close.lowerBound]
            let name = tagName(of: tagBody)
            // Only opening tags drive blocks; closing tags (`/…`) advance.
            guard !name.isEmpty, !name.hasPrefix("/") else {
                cursor = close.upperBound
                continue
            }
            if let (emitted, next) = block(named: name, openTag: open, closeTag: close, in: html, baseURL: baseURL) {
                blocks.append(contentsOf: emitted)
                cursor = next
            } else {
                // Unrecognized tag — skip it and keep scanning its contents.
                cursor = close.upperBound
            }
        }
        return blocks
    }

    /// Dispatch one opening tag to its block builder (`nil` => unrecognized).
    /// Returns the emitted blocks (0, 1, or — for a multi-paragraph
    /// `<blockquote>`, DUT-655 — several) plus the next cursor.
    private static func block(
        named name: String,
        openTag open: Range<String.Index>,
        closeTag close: Range<String.Index>,
        in html: String,
        baseURL: URL?
    ) -> ([ArticleBlock], String.Index)? {
        if name == "img" {
            let image = imageBlock(fromTag: html[open.upperBound..<close.lowerBound], baseURL: baseURL)
            return (image.map { [$0] } ?? [], close.upperBound)
        }
        if depthTrackedContainers.contains(name) {
            guard
                let inner = ArticleBodyExtractor.sliceUntilMatchingClose(
                    in: html,
                    openTag: "<\(name)",
                    closeTag: "</\(name)>",
                    bodyStart: close.upperBound
                )
            else {
                return ([], close.upperBound)
            }
            let next = html.index(close.upperBound, offsetBy: inner.count)
            return (
                containerBlocks(name: name, inner: inner, baseURL: baseURL),
                advance(past: "</\(name)>", from: next, in: html)
            )
        }
        if name == "p" || isHeading(name) {
            let (inner, next) = sliceSimpleClose(name: name, from: close.upperBound, in: html)
            return (textBlock(name: name, inner: inner).map { [$0] } ?? [], next)
        }
        return nil
    }

    /// Build a depth-tracked container block (`figure`/`ul`/`ol`/`blockquote`).
    ///
    /// DUT-655: `figure`/`ul`/`ol` yield a single block; a `<blockquote>`
    /// wrapping several `<p>` children yields ONE paragraph block per child
    /// (see ``blockquoteBlocks``). `containerBlock` therefore returns a list —
    /// the caller appends whatever it produces — instead of a single block.
    private static func containerBlocks<S: StringProtocol>(name: String, inner: S, baseURL: URL?) -> [ArticleBlock]
    where S.Index == String.Index {
        switch name {
        case "figure": return figureBlock(inner: inner, baseURL: baseURL).map { [$0] } ?? []
        case "ul": return listBlock(inner: inner, ordered: false).map { [$0] } ?? []
        case "ol": return listBlock(inner: inner, ordered: true).map { [$0] } ?? []
        case "blockquote": return blockquoteBlocks(inner: inner)
        default: return []
        }
    }

    /// Build a `.heading` / `.paragraph` from a `<p>` or `<h1…6>`, or nil.
    private static func textBlock(name: String, inner: Substring) -> ArticleBlock? {
        let text = inlineAttributedString(from: inner)
        guard !text.runs.isEmpty else { return nil }
        if isHeading(name), let last = name.last, let level = Int(String(last)) {
            return .heading(level: min(6, max(1, level)), text: text)
        }
        return .paragraph(text)
    }

    // MARK: - Images

    /// Build an `.image` from a `<figure>` (caption = `<figcaption>` else `alt`).
    private static func figureBlock<S: StringProtocol>(inner: S, baseURL: URL?) -> ArticleBlock? {
        guard let imgTag = firstTagBody(named: "img", in: inner) else { return nil }
        guard let url = imageURL(fromTag: imgTag, baseURL: baseURL) else { return nil }
        let caption = figcaptionText(in: inner)
        return .image(url: url, caption: caption ?? altCaption(in: imgTag))
    }

    /// Build an `.image` from a standalone `<img>` (caption = `alt` else nil).
    private static func imageBlock<S: StringProtocol>(fromTag tagBody: S, baseURL: URL?) -> ArticleBlock? {
        guard let url = imageURL(fromTag: tagBody, baseURL: baseURL) else { return nil }
        return .image(url: url, caption: altCaption(in: tagBody))
    }

    /// The `alt` attribute, decoded + edge-trimmed, as a caption (nil if empty).
    private static func altCaption<S: StringProtocol>(in tagBody: S) -> String? {
        let alt = HTMLSanitizer.decodingEntities(attributeValue("alt", in: tagBody))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return alt.isEmpty ? nil : alt
    }

    /// Extract the inline text of the first `<figcaption>` in `inner`, or nil.
    private static func figcaptionText<S: StringProtocol>(in inner: S) -> String? {
        guard
            let open = inner.range(of: "<figcaption", options: .caseInsensitive),
            let openEnd = inner.range(of: ">", range: open.upperBound..<inner.endIndex),
            let closeRange = inner.range(
                of: "</figcaption>",
                options: .caseInsensitive,
                range: openEnd.upperBound..<inner.endIndex
            )
        else {
            return nil
        }
        let text = inlineAttributedString(from: inner[openEnd.upperBound..<closeRange.lowerBound])
        guard !text.runs.isEmpty else { return nil }
        return String(text.characters)
    }

    // MARK: - Lists / blockquote
    //
    // `listBlock`, `sliceMatchingLI`, and `blockquoteBlocks` live in
    // `ArticleHTMLParser+Blocks.swift` (DUT-655 — file_length cap).

    // MARK: - Inline → AttributedString

    /// Active inline formatting while scanning a block's inner HTML.
    private struct InlineState {
        var boldDepth = 0
        var italicDepth = 0
        var link: URL?

        /// The combined presentation intent for the current depths, or nil.
        var intent: InlinePresentationIntent? {
            switch (boldDepth > 0, italicDepth > 0) {
            case (true, true): return [.stronglyEmphasized, .emphasized]
            case (true, false): return .stronglyEmphasized
            case (false, true): return .emphasized
            case (false, false): return nil
            }
        }
    }

    /// Inline-parse a block's inner HTML into an ``AttributedString``.
    ///
    /// State machine tracking bold-depth, italic-depth and the current link
    /// URL. Each text run is entity-decoded, has whitespace collapsed (boundary
    /// spaces preserved) and carries the active attributes; result is trimmed.
    static func inlineAttributedString<S: StringProtocol>(from html: S) -> AttributedString {
        var result = AttributedString()
        var state = InlineState()
        var cursor = html.startIndex
        while cursor < html.endIndex {
            if html[cursor] == "<" {
                if let close = html.range(of: ">", range: cursor..<html.endIndex) {
                    applyTag(html[html.index(after: cursor)..<close.lowerBound], state: &state, into: &result)
                    cursor = close.upperBound
                } else {
                    // Lone `<` with no closing `>` (e.g. prose like
                    // "Cook for <5 min"): emit it as a literal character so the
                    // cursor always advances. Without this, the run-accumulation
                    // below finds the same `<` at `cursor`, `runEnd == cursor`,
                    // the cursor never moves, and the parse hangs the article
                    // screen on any stray `<`. (review DOD-ART-1)
                    appendTextRun("<", state: state, into: &result)
                    cursor = html.index(after: cursor)
                }
                continue
            }
            // Accumulate a text run up to the next `<`.
            let runEnd = html.range(of: "<", range: cursor..<html.endIndex)?.lowerBound ?? html.endIndex
            appendTextRun(html[cursor..<runEnd], state: state, into: &result)
            cursor = runEnd
        }
        return trimmingWhitespace(result)
    }

    /// Mutate inline state for one tag (emphasis / link / `<br>`); else ignore.
    private static func applyTag<S: StringProtocol>(
        _ tagBody: S,
        state: inout InlineState,
        into result: inout AttributedString
    ) {
        switch tagName(of: tagBody) {
        case "strong", "b": state.boldDepth += 1
        case "/strong", "/b": state.boldDepth = max(0, state.boldDepth - 1)
        case "em", "i": state.italicDepth += 1
        case "/em", "/i": state.italicDepth = max(0, state.italicDepth - 1)
        case "a": state.link = Self.resolvedLinkURL(inTag: tagBody)
        case "/a": state.link = nil
        case "br", "br/": result.append(AttributedString("\n"))
        default: break
        }
    }

    /// Decode + collapse one text run and append it with the active attributes.
    private static func appendTextRun<S: StringProtocol>(
        _ raw: S,
        state: InlineState,
        into result: inout AttributedString
    ) {
        guard !raw.isEmpty else { return }
        let collapsed = collapsePreservingEdges(HTMLSanitizer.decodingEntities(String(raw)))
        guard !collapsed.isEmpty else { return }
        var run = AttributedString(collapsed)
        if let intent = state.intent { run.inlinePresentationIntent = intent }
        if let link = state.link { run.link = link }
        result.append(run)
    }

    // MARK: - Tag / attribute helpers

    /// Strip every `<tag>…</tag>` block — `<script>` / `<style>` / `<svg>` etc.
    static func removeBlock(tag: String, from html: String) -> String {
        var output = html
        let closeMarker = "</\(tag)>"
        while let open = output.range(of: "<\(tag)", options: .caseInsensitive) {
            guard
                let close = output.range(
                    of: closeMarker,
                    options: .caseInsensitive,
                    range: open.upperBound..<output.endIndex
                )
            else {
                // Unterminated — drop to the end so raw script text never leaks.
                output.removeSubrange(open.lowerBound..<output.endIndex)
                break
            }
            output.removeSubrange(open.lowerBound..<close.upperBound)
        }
        return output
    }

    /// Slice a non-nesting `<name>…</name>` body: inner substring + next cursor.
    static func sliceSimpleClose<S: StringProtocol>(
        name: String,
        from bodyStart: S.Index,
        in html: S
    ) -> (S.SubSequence, S.Index) where S.Index == String.Index {
        guard
            let close = html.range(
                of: "</\(name)>",
                options: .caseInsensitive,
                range: bodyStart..<html.endIndex
            )
        else {
            return (html[bodyStart..<html.endIndex], html.endIndex)
        }
        return (html[bodyStart..<close.lowerBound], close.upperBound)
    }

    /// Return the inner body of the first `<name …>…</name>` in `html`, or nil.
    private static func firstTagBody<S: StringProtocol>(named name: String, in html: S) -> S.SubSequence? {
        guard
            let open = html.range(of: "<\(name)", options: .caseInsensitive),
            let close = html.range(of: ">", range: open.upperBound..<html.endIndex)
        else {
            return nil
        }
        return html[open.upperBound..<close.lowerBound]
    }

    /// Lowercased tag name: first token, keeping a leading `/` for close tags.
    static func tagName<S: StringProtocol>(of tagBody: S) -> String {
        var name = ""
        for character in tagBody {
            if character.isWhitespace { break }
            name.append(character)
        }
        return name.lowercased()
    }

    /// Whether `name` is an `h1`…`h6` heading tag.
    private static func isHeading(_ name: String) -> Bool {
        guard name.count == 2, name.hasPrefix("h"), let last = name.last, let level = Int(String(last)) else {
            return false
        }
        return (1...6).contains(level)
    }

    /// Read `attribute="…"` / `attribute='…'` (case-insensitive), or "" when
    /// absent. Matches a whole token so a `src` lookup never returns `srcset`.
    static func attributeValue<S: StringProtocol>(_ attribute: String, in tagBody: S) -> String {
        let body = String(tagBody)
        var search = body.startIndex
        while let found = body.range(of: attribute, options: .caseInsensitive, range: search..<body.endIndex) {
            search = found.upperBound
            // Char before must be a boundary so `src` doesn't match `srcset`.
            if found.lowerBound > body.startIndex {
                let before = body[body.index(before: found.lowerBound)]
                if !before.isWhitespace { continue }
            }
            var index = found.upperBound
            while index < body.endIndex, body[index].isWhitespace { index = body.index(after: index) }
            guard index < body.endIndex, body[index] == "=" else { continue }
            index = body.index(after: index)
            while index < body.endIndex, body[index].isWhitespace { index = body.index(after: index) }
            guard index < body.endIndex else { return "" }
            let quote = body[index]
            guard quote == "\"" || quote == "'" else { continue }
            let valueStart = body.index(after: index)
            guard let valueEnd = body[valueStart...].firstIndex(of: quote) else { return "" }
            return String(body[valueStart..<valueEnd])
        }
        return ""
    }

    // MARK: - Whitespace

    /// Advance `index` past the first `marker` (close tag), else return it as-is.
    private static func advance(past marker: String, from index: String.Index, in html: String) -> String.Index {
        guard let range = html.range(of: marker, options: .caseInsensitive, range: index..<html.endIndex) else {
            return index
        }
        return range.upperBound
    }

    /// Collapse internal whitespace to single spaces, preserving one leading /
    /// trailing space when present (so spaces between adjacent inline runs live).
    private static func collapsePreservingEdges(_ input: String) -> String {
        guard !input.isEmpty else { return "" }
        let leading = input.first?.isWhitespace == true
        let trailing = input.last?.isWhitespace == true
        let core = input.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if core.isEmpty { return (leading || trailing) ? " " : "" }
        return (leading ? " " : "") + core + (trailing ? " " : "")
    }

    /// Edge-trim whitespace from an ``AttributedString``, keeping interior runs.
    private static func trimmingWhitespace(_ value: AttributedString) -> AttributedString {
        var result = value
        while let first = result.characters.first, first.isWhitespace || first.isNewline {
            result.removeSubrange(result.startIndex..<result.index(afterCharacter: result.startIndex))
        }
        while let last = result.characters.last, last.isWhitespace || last.isNewline {
            let lastIndex = result.index(beforeCharacter: result.endIndex)
            result.removeSubrange(lastIndex..<result.endIndex)
        }
        return result
    }
}

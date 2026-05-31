import Foundation

/// Extracts the readable article body from a rendered WordPress HTML page.
///
/// Used by the recipe-detail fetch path (US-37 / CL-63 / T-640) when JSON-LD
/// parse fails: the post is reclassified as an article and rendered with
/// the extracted body in ``DODFeatureRecipeDetail/ArticleDetailView``
/// instead of being hidden from lists per the pre-T-640 CL-9 contract.
///
/// **Strategy (CL-63 decision 4):**
/// 1. Find the first `<div class="entry-content">` block — WordPress's
///    standard article-body wrapper that Yoast / WPRM / most WP themes
///    preserve.
/// 2. Fall back to the first `<article>...</article>` block.
/// 3. Fall back to the first `<main>...</main>` block.
/// 4. Fall back to the `<body>...</body>` block.
/// 5. If all four fail, return an empty string and the view-model
///    transitions to ``RecipeDetailViewModel/LoadState/unavailable`` (the
///    final fallback — both JSON-LD and article-body extraction failed,
///    meaning the post page is genuinely unrenderable).
///
/// The selected slice is run through ``HTMLSanitizer/plainText(from:)``
/// to strip tags, decode entities, and collapse whitespace. Plain-text
/// rendering satisfies the v1 spec contract per CL-63 — rich HTML rendering
/// (preserve `<h2>` / `<ul>` / `<a href>` formatting) is a v1.x follow-up.
///
/// Not a general-purpose HTML parser — handles the narrow shape WordPress
/// produces. Robust to attribute re-ordering and extra whitespace; assumes
/// well-formed closing tags.
public enum ArticleBodyExtractor {

    /// Extract a sanitized plain-text article body from the rendered HTML
    /// of a WordPress post page.
    ///
    /// - Parameter html: the full rendered HTML page (the same string
    ///   ``DODNetworking/RecipePageFetcher/html(for:)`` produces).
    /// - Returns: a sanitized plain-text body, or empty string if no
    ///   suitable container was found.
    public static func extract(html: String) -> String {
        // 1. Try the canonical WordPress `entry-content` wrapper first.
        if let slice = extractEntryContentSlice(in: html) {
            return HTMLSanitizer.plainText(from: slice)
        }
        // 2. Fall back to `<article>` (HTML5 semantic tag — many themes wrap
        //    the article body in this).
        if let slice = extractFirstBlock(tag: "article", in: html) {
            return HTMLSanitizer.plainText(from: slice)
        }
        // 3. Fall back to `<main>` (HTML5 — themes that don't ship an
        //    `<article>` element often wrap content in `<main>`).
        if let slice = extractFirstBlock(tag: "main", in: html) {
            return HTMLSanitizer.plainText(from: slice)
        }
        // 4. Fall back to `<body>` — last-ditch effort. Will include
        //    navigation chrome, but sanitizing collapses obviously-empty
        //    blocks and the result is at least readable.
        if let slice = extractFirstBlock(tag: "body", in: html) {
            return HTMLSanitizer.plainText(from: slice)
        }
        return ""
    }

    /// Extract the article body as **HTML** (not plain text) — the rich
    /// counterpart to ``extract(html:)`` (DOD-ART-1). Returns the
    /// `entry-content` slice verbatim (falling back to `<article>` / `<main>`
    /// / `<body>`) so ``ArticleHTMLParser`` can render it as native blocks —
    /// headings, photos, lists, and tappable links — instead of the v1
    /// plain-text wall that collapsed round-up posts (US-37 / CL-63 rich-
    /// rendering follow-up). Script/style blocks are left in place; the
    /// parser drops them at render time.
    ///
    /// Stored in `Recipe.articleBodyHTML` (the field name has always implied
    /// HTML; before DOD-ART-1 it actually held stripped plain text). The only
    /// consumer that reads the *content* is `ArticleDetailView`; every other
    /// site treats the field as a non-empty "is renderable article" flag, so
    /// switching the stored form from plain text to HTML is behavior-safe.
    public static func extractContentHTML(html: String) -> String {
        if let slice = extractEntryContentSlice(in: html) {
            return slice
        }
        if let slice = extractFirstBlock(tag: "article", in: html) {
            return slice
        }
        if let slice = extractFirstBlock(tag: "main", in: html) {
            return slice
        }
        if let slice = extractFirstBlock(tag: "body", in: html) {
            return slice
        }
        return ""
    }

    // MARK: - Helpers

    /// Find the first `<div class="entry-content">…</div>` block. WP wraps
    /// the post body in this div by default; the regex tolerates additional
    /// classes (`class="entry-content single-post"` etc.) and arbitrary
    /// attribute ordering, but assumes the class appears as a complete
    /// whitespace-delimited token.
    static func extractEntryContentSlice(in html: String) -> String? {
        // Find an opening `<div ...>` whose attributes contain
        // `class="..."` with `entry-content` as one of the whitespace-
        // delimited class tokens. The naive approach (search for the literal
        // string `entry-content`) is good enough for WP's output — WP
        // doesn't ship two divs where one merely *contains* the substring
        // "entry-content" inside an unrelated attribute value.
        var cursor = html.startIndex
        let openMarker = "<div"
        let closeMarker = "</div>"
        while cursor < html.endIndex {
            guard
                let openTagStart = html.range(of: openMarker, options: .caseInsensitive, range: cursor..<html.endIndex)
            else {
                return nil
            }
            guard let openTagEnd = html.range(of: ">", range: openTagStart.upperBound..<html.endIndex) else {
                return nil
            }
            let attributes = html[openTagStart.upperBound..<openTagEnd.lowerBound]
            if hasClassToken(attributes: attributes, token: "entry-content") {
                // Found it. Walk `<div>` nesting to find the matching close.
                let slice = sliceUntilMatchingClose(
                    in: html,
                    openTag: "<div",
                    closeTag: closeMarker,
                    bodyStart: openTagEnd.upperBound
                )
                return slice
            }
            cursor = openTagEnd.upperBound
        }
        return nil
    }

    /// Find the first `<tag>…</tag>` block in `html`. Tag names are matched
    /// case-insensitively; attributes are ignored. Used for `<article>`,
    /// `<main>`, `<body>` — none of which nest in well-formed WP output, so
    /// the simple non-nesting extraction is sufficient.
    static func extractFirstBlock(tag: String, in html: String) -> String? {
        let openMarker = "<\(tag)"
        let closeMarker = "</\(tag)>"
        guard let openTagStart = html.range(of: openMarker, options: .caseInsensitive) else {
            return nil
        }
        guard let openTagEnd = html.range(of: ">", range: openTagStart.upperBound..<html.endIndex) else {
            return nil
        }
        guard
            let closeTagRange = html.range(
                of: closeMarker,
                options: .caseInsensitive,
                range: openTagEnd.upperBound..<html.endIndex
            )
        else {
            return nil
        }
        return String(html[openTagEnd.upperBound..<closeTagRange.lowerBound])
    }

    /// Check whether an attribute string contains a class token. Tolerates
    /// `class='entry-content'`, `class="entry-content"`, `class="foo entry-content bar"`,
    /// and ignores attributes whose values happen to contain the token as a
    /// substring (e.g. `data-class="not-entry-content"`).
    static func hasClassToken<S: StringProtocol>(attributes: S, token: String) -> Bool {
        // Find a `class=` attribute. Naive but adequate — WP doesn't ship
        // attribute names that contain the substring `class` outside of
        // the actual `class` attribute (no `dataclass`, no `myclass-foo`).
        let attrString = String(attributes)
        guard let classRange = attrString.range(of: "class", options: .caseInsensitive) else {
            return false
        }
        // Skip whitespace and find the opening quote.
        var index = classRange.upperBound
        while index < attrString.endIndex, attrString[index].isWhitespace || attrString[index] == "=" {
            index = attrString.index(after: index)
        }
        guard index < attrString.endIndex else { return false }
        let quote = attrString[index]
        guard quote == "\"" || quote == "'" else {
            // Unquoted attribute — single token only. Compare to the
            // remainder of the attribute string up to whitespace.
            let tail = attrString[index...]
            let firstToken = tail.split(whereSeparator: { $0.isWhitespace }).first ?? ""
            return String(firstToken) == token
        }
        let valueStart = attrString.index(after: index)
        guard let valueEnd = attrString[valueStart...].firstIndex(of: quote) else {
            return false
        }
        let classValue = attrString[valueStart..<valueEnd]
        // Whitespace-delimited token match — `entry-content` must appear as
        // a complete token in the space-separated class list.
        return classValue.split(whereSeparator: { $0.isWhitespace }).map(String.init).contains(token)
    }

    /// Walk forward through `html` from `bodyStart`, tracking nesting of
    /// `openTag` (e.g. `<div`) and finding the matching `closeTag` (e.g.
    /// `</div>`). Returns the slice between `bodyStart` and the matching
    /// close, or nil if nesting never balances.
    static func sliceUntilMatchingClose(
        in html: String,
        openTag: String,
        closeTag: String,
        bodyStart: String.Index
    ) -> String? {
        var depth = 1
        var cursor = bodyStart
        while cursor < html.endIndex, depth > 0 {
            let nextOpenRange = html.range(of: openTag, options: .caseInsensitive, range: cursor..<html.endIndex)
            let nextCloseRange = html.range(of: closeTag, options: .caseInsensitive, range: cursor..<html.endIndex)
            guard let nextClose = nextCloseRange else { return nil }
            if let nextOpen = nextOpenRange, nextOpen.lowerBound < nextClose.lowerBound {
                depth += 1
                // Advance past the opening tag's `>` so a malformed `<divx>`
                // (which we shouldn't match against `<div`) doesn't trip us.
                if let openTagEnd = html.range(of: ">", range: nextOpen.upperBound..<html.endIndex) {
                    cursor = openTagEnd.upperBound
                } else {
                    cursor = nextOpen.upperBound
                }
            } else {
                depth -= 1
                if depth == 0 {
                    return String(html[bodyStart..<nextClose.lowerBound])
                }
                cursor = nextClose.upperBound
            }
        }
        return nil
    }
}

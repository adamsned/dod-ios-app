import Foundation

/// Extracts ingredient + instruction text from the WP Recipe Maker (WPRM)
/// recipe card embedded in a rendered `dutchovendaddy.com` post page.
///
/// **Why this exists (DUT-42).** ``DODNetworking/JSONLDRecipeParser`` is the
/// primary source for recipe detail: it reads `recipeIngredient` /
/// `recipeInstructions` off the page's JSON-LD `Recipe` node. Some posts ship
/// a `Recipe` node that OMITS those fields even though the data is present in
/// the page as server-rendered WPRM HTML (confirmed: `dutch-oven-7-can-soup`,
/// 2026-06-04 — its JSON-LD `Recipe` has `name` but no
/// `recipeIngredient`/`recipeInstructions`). Those recipes rendered with an
/// empty ingredient + instruction list. This parser is the per-field
/// fallback: when the JSON-LD list is empty, fill it from the WPRM card.
///
/// **Strategy.** A custom string tokenizer (NO HTML-parser dependency — the
/// constitution forbids adding one, and this mirrors ``ArticleBodyExtractor``,
/// whose `hasClassToken` / `sliceUntilMatchingClose` scanning helpers this type
/// reuses):
/// 1. Slice the `<div class="wprm-recipe-container">` block (the wrapper every
///    WPRM theme emits). Nothing outside it is considered.
/// 2. Ingredients — collect every `<li class="wprm-recipe-ingredient">` row,
///    dropping its leading `<span class="wprm-checkbox-container">` subtree (a
///    screen-reader checkbox glyph that must not leak into the text), then
///    plain-texting the amount / unit / name / notes spans that remain. When a
///    card has NO line rows at all (the 7 Can Soup shape — the author entered
///    each ingredient as a `<h4 class="wprm-recipe-ingredient-group-name">`
///    group header), fall back to the group-name headers: with no line rows
///    present, the group names ARE the ingredients.
/// 3. Instructions — collect every `<li class="wprm-recipe-instruction">` row
///    (inner `wprm-recipe-instruction-text`, else the whole row). When the card
///    has NO instruction rows (7 Can Soup / DUT-538 — steps live as a numbered
///    "How to Make" list in the post body), fall back to the page's Gutenberg
///    `is-style-circle-number-list` rows — the one place we read outside the card.
///
/// Not a general-purpose HTML parser — handles the narrow, well-formed shape
/// WPRM produces. Robust to attribute re-ordering and extra whitespace; assumes
/// well-formed closing tags. Returns empty lists when no card / no rows are
/// present (the caller keeps whatever it already had).
public enum WPRMRecipeCardParser {

    /// The parsed result: plain-text ingredient + instruction lines in document
    /// order. Either may be empty (no card, or the card had only one of the two).
    public struct Card: Sendable, Equatable {
        public let ingredients: [String]
        public let instructions: [String]

        public init(ingredients: [String], instructions: [String]) {
            self.ingredients = ingredients
            self.instructions = instructions
        }
    }

    /// Class token on the wrapper div every WPRM theme renders.
    static let containerToken = "wprm-recipe-container"
    /// Class token on each ingredient line row (`<li>`).
    static let ingredientRowToken = "wprm-recipe-ingredient"
    /// Class token on each ingredient group header (`<h4>`) — the fallback
    /// ingredient source when a card carries no line rows.
    static let ingredientGroupNameToken = "wprm-recipe-ingredient-group-name"
    /// Class token on each instruction line row (`<li>`).
    static let instructionRowToken = "wprm-recipe-instruction"
    /// Class token on the inner text wrapper of an instruction row.
    static let instructionTextToken = "wprm-recipe-instruction-text"
    /// Class token on the Gutenberg numbered-step `<ol>` WPRM renders into the
    /// post body's "How to Make" section (DUT-538). Used as the instruction
    /// fallback when the WPRM card itself carries no `wprm-recipe-instruction`
    /// rows — the steps live here as `<li>` "Step N: …" rows instead.
    static let numberedStepListToken = "is-style-circle-number-list"
    /// Class token on the checkbox span that prefixes an ingredient row; its
    /// subtree carries a screen-reader ballot-box glyph (`&#9634;`) and is
    /// dropped before the row text is extracted.
    static let checkboxContainerToken = "wprm-checkbox-container"

    /// Parse the WPRM card out of a rendered post page.
    ///
    /// - Parameter html: the full rendered HTML page (the same string
    ///   ``DODNetworking/RecipePageFetcher`` produces).
    /// - Returns: a ``Card`` with plain-text ingredient + instruction lines.
    ///   Empty lists when no card / no rows are found.
    public static func parse(html: String) -> Card {
        guard let card = sliceRecipeContainer(in: html) else {
            return Card(ingredients: [], instructions: [])
        }
        return Card(
            ingredients: parseIngredients(in: card),
            instructions: parseInstructions(in: card, page: html)
        )
    }

    /// Whether the page carries a WP Recipe Maker card
    /// (`<div class="wprm-recipe-container">`). DUT-538: a page WITH a WPRM
    /// card is a recipe — even if a first parse came back thin — and must not
    /// be reclassified as an article that dumps the whole blog body.
    public static func hasRecipeCard(html: String) -> Bool {
        sliceRecipeContainer(in: html) != nil
    }

    // MARK: - Container slice

    /// Slice the first `<div ...>` whose `class=` contains ``containerToken``,
    /// depth-tracking `<div>` nesting to its matching close. Returns the inner
    /// body, or nil if no container is present.
    static func sliceRecipeContainer(in html: String) -> String? {
        var cursor = html.startIndex
        while cursor < html.endIndex {
            guard
                let openStart = html.range(of: "<div", options: .caseInsensitive, range: cursor..<html.endIndex)
            else {
                return nil
            }
            guard let openEnd = html.range(of: ">", range: openStart.upperBound..<html.endIndex) else {
                return nil
            }
            let attributes = html[openStart.upperBound..<openEnd.lowerBound]
            if ArticleBodyExtractor.hasClassToken(attributes: attributes, token: containerToken) {
                return ArticleBodyExtractor.sliceUntilMatchingClose(
                    in: html,
                    openTag: "<div",
                    closeTag: "</div>",
                    bodyStart: openEnd.upperBound
                )
            }
            cursor = openEnd.upperBound
        }
        return nil
    }

    // MARK: - Ingredients

    /// Collect ingredient lines. Prefer `<li class="wprm-recipe-ingredient">`
    /// line rows; when the card has none, fall back to
    /// `<h4 class="wprm-recipe-ingredient-group-name">` group headers.
    static func parseIngredients(in card: String) -> [String] {
        let rows = collectElementTexts(
            in: card,
            tag: "li",
            classToken: ingredientRowToken,
            transform: ingredientRowText
        )
        if !rows.isEmpty {
            return rows
        }
        return collectElementTexts(
            in: card,
            tag: "h4",
            classToken: ingredientGroupNameToken,
            transform: HTMLSanitizer.plainText(from:)
        )
    }

    /// Plain-text one ingredient `<li>` body, first dropping the leading
    /// `<span class="wprm-checkbox-container">` subtree (the screen-reader
    /// checkbox glyph) so it never leaks into the amount/unit/name text.
    static func ingredientRowText(_ rowInner: String) -> String {
        HTMLSanitizer.plainText(from: removingCheckboxContainer(from: rowInner))
    }

    /// Remove the `<span class="wprm-checkbox-container">…</span>` subtree from
    /// an ingredient row body, depth-tracking `<span>` nesting. Returns the body
    /// unchanged when no checkbox container is present.
    static func removingCheckboxContainer(from rowInner: String) -> String {
        var cursor = rowInner.startIndex
        while cursor < rowInner.endIndex {
            guard
                let openStart = rowInner.range(
                    of: "<span",
                    options: .caseInsensitive,
                    range: cursor..<rowInner.endIndex
                )
            else {
                return rowInner
            }
            guard let openEnd = rowInner.range(of: ">", range: openStart.upperBound..<rowInner.endIndex) else {
                return rowInner
            }
            let attributes = rowInner[openStart.upperBound..<openEnd.lowerBound]
            if ArticleBodyExtractor.hasClassToken(attributes: attributes, token: checkboxContainerToken) {
                guard
                    let inner = ArticleBodyExtractor.sliceUntilMatchingClose(
                        in: rowInner,
                        openTag: "<span",
                        closeTag: "</span>",
                        bodyStart: openEnd.upperBound
                    )
                else {
                    return rowInner
                }
                let closeStart = rowInner.index(openEnd.upperBound, offsetBy: inner.count)
                var result = rowInner
                // Drop `<span class="wprm-checkbox-container"> … </span>` whole.
                if let closeRange = rowInner.range(of: "</span>", range: closeStart..<rowInner.endIndex) {
                    result.removeSubrange(openStart.lowerBound..<closeRange.upperBound)
                }
                return result
            }
            cursor = openEnd.upperBound
        }
        return rowInner
    }

    // MARK: - Instructions

    /// Collect instruction lines from `<li class="wprm-recipe-instruction">`
    /// rows, preferring the inner `wprm-recipe-instruction-text` wrapper. When
    /// the card carries NO instruction rows (DUT-538 — the 7 Can Soup shape,
    /// where the steps live in the post body's "How to Make" numbered list
    /// rather than in the WPRM card), fall back to the page's Gutenberg
    /// numbered-step lists.
    ///
    /// - Parameters:
    ///   - card: the sliced `wprm-recipe-container` body (searched first).
    ///   - page: the full rendered page (searched only for the fallback, since
    ///     the "How to Make" list sits OUTSIDE the recipe card).
    static func parseInstructions(in card: String, page: String) -> [String] {
        let cardRows = collectElementTexts(
            in: card,
            tag: "li",
            classToken: instructionRowToken,
            transform: instructionRowText
        )
        if !cardRows.isEmpty {
            return cardRows
        }
        return parseNumberedStepList(in: page)
    }

    /// DUT-538 fallback: collect step text from every
    /// `<ol class="…is-style-circle-number-list…">` in the page. WPRM renders
    /// the "How to Make" steps as one such `<ol>` per step (each holding a
    /// single `<li>`), so flattening the `<li>` rows across all matching lists
    /// yields the ordered steps. Class-token matched so it ignores the page's
    /// other `<ol>`s (table of contents, comment list) that use different
    /// classes.
    static func parseNumberedStepList(in page: String) -> [String] {
        collectElementInners(in: page, tag: "ol", classToken: numberedStepListToken)
            .flatMap { listInner in
                collectElementTexts(
                    in: listInner,
                    tag: "li",
                    classToken: nil,
                    transform: HTMLSanitizer.plainText(from:)
                )
            }
    }

    /// Plain-text one instruction `<li>` body: prefer the inner
    /// `<div class="wprm-recipe-instruction-text">` content; fall back to the
    /// whole row when that wrapper is absent.
    static func instructionRowText(_ rowInner: String) -> String {
        if let text = firstElementInner(in: rowInner, tag: "div", classToken: instructionTextToken) {
            return HTMLSanitizer.plainText(from: text)
        }
        return HTMLSanitizer.plainText(from: rowInner)
    }

    // MARK: - Generic element collection

    /// Walk `html` collecting the transformed inner text of every
    /// `<tag …>…</tag>` whose `class=` contains `classToken`, depth-tracking
    /// `<tag>` nesting. Blank results (after `transform`) are dropped. Pass a
    /// nil `classToken` to collect EVERY `<tag>` regardless of class (used to
    /// pull every `<li>` out of an already class-scoped `<ol>`).
    static func collectElementTexts(
        in html: String,
        tag: String,
        classToken: String?,
        transform: (String) -> String
    ) -> [String] {
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
            let skipTag = classToken.map {
                !ArticleBodyExtractor.hasClassToken(attributes: attributes, token: $0)
            }
            if skipTag == true {
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
            let text = transform(inner)
            if !text.isEmpty {
                results.append(text)
            }
            // Advance past this element's matching close so nested same-tag
            // children aren't re-collected as separate rows.
            cursor = html.index(openEnd.upperBound, offsetBy: inner.count)
            if let closeRange = html.range(of: closeMarker, range: cursor..<html.endIndex) {
                cursor = closeRange.upperBound
            }
        }
        return results
    }

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

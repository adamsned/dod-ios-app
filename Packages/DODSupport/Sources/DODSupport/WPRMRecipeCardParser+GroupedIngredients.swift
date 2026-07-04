import Foundation

/// DUT-550: header-only ingredient-group recovery for cards that MIX normal
/// `<li class="wprm-recipe-ingredient">` rows with header-only groups. Split out
/// of ``WPRMRecipeCardParser`` so the main type stays under SwiftLint's
/// `type_body_length` / `file_length` caps (mirrors the DUT-544 `+StepRegion`
/// split).
extension WPRMRecipeCardParser {

    /// Class token on the `<div>` wrapping one ingredient group (its `<h4>`
    /// group-name header plus, when present, its `<ul>` of line rows).
    static let ingredientGroupToken = "wprm-recipe-ingredient-group"

    /// DUT-557: collect ingredient lines in a SINGLE document-order pass over the
    /// card's `wprm-recipe-ingredient-group` `<div>`s, emitting — for each group,
    /// in the order the groups appear — either that group's `<li>` line rows OR
    /// (when the group is header-only) its group name. This replaces the
    /// pre-DUT-557 `rows + headerOnlyGroupNames` concatenation, which scanned the
    /// two shapes separately and so moved a header-only group that PRECEDES a
    /// line-row group to the end of the list.
    ///
    /// When the card has NO grouped structure at all (bare
    /// `<ul class="wprm-recipe-ingredients">` rows — the common shape), fall back
    /// to a flat line-row scan so the ordinary case is unchanged.
    static func ingredientsInDocumentOrder(in card: String) -> [String] {
        let groups = collectElementInners(in: card, tag: "div", classToken: ingredientGroupToken)
        guard !groups.isEmpty else {
            return collectElementTexts(
                in: card,
                tag: "li",
                classToken: ingredientRowToken,
                transform: ingredientRowText
            )
        }
        return groups.flatMap(ingredientsInGroup)
    }

    /// The ingredient lines contributed by ONE `wprm-recipe-ingredient-group`
    /// `<div>` body: its `<li class="wprm-recipe-ingredient">` line rows when it
    /// has any, otherwise its header-only group name (the per-group DUT-42
    /// quirk). A group that carries line rows keeps its `<h4>` name dropped — it's
    /// a section label, already represented by its rows.
    static func ingredientsInGroup(_ groupInner: String) -> [String] {
        let rows = collectElementTexts(
            in: groupInner,
            tag: "li",
            classToken: ingredientRowToken,
            transform: ingredientRowText
        )
        if !rows.isEmpty {
            return rows
        }
        return groupNameIfHeaderOnly(groupInner).map { [$0] } ?? []
    }

    /// Collect the group names of HEADER-ONLY ingredient groups — a
    /// `wprm-recipe-ingredient-group` `<div>` carrying a
    /// `wprm-recipe-ingredient-group-name` `<h4>` but NO
    /// `wprm-recipe-ingredient` `<li>` descendant. Those group names ARE
    /// ingredients (the per-group DUT-42 quirk); groups that DO have line rows
    /// keep their name dropped (it's a section label, collected as line rows
    /// instead).
    ///
    /// Order-preserving across the groups it emits. Empty when the card has no
    /// grouped structure (bare `<ul>` rows — the common shape) or when every
    /// group already carries line rows. Retained for callers/tests that probe the
    /// header-only slice directly; the primary ingredient path is
    /// ``ingredientsInDocumentOrder(in:)`` (DUT-557).
    static func headerOnlyGroupNames(in card: String) -> [String] {
        collectElementInners(in: card, tag: "div", classToken: ingredientGroupToken)
            .compactMap(groupNameIfHeaderOnly)
    }

    /// The plain-text group name of a single `wprm-recipe-ingredient-group`
    /// `<div>` body, but ONLY when the group is header-only (no
    /// `wprm-recipe-ingredient` `<li>` descendant). Returns nil for groups that
    /// carry line rows (their name is a label) or that have no group-name `<h4>`.
    static func groupNameIfHeaderOnly(_ groupInner: String) -> String? {
        guard !groupContainsLineRow(groupInner) else { return nil }
        guard let name = firstElementInner(in: groupInner, tag: "h4", classToken: ingredientGroupNameToken)
        else { return nil }
        let text = HTMLSanitizer.plainText(from: name)
        return text.isEmpty ? nil : text
    }

    /// Whether an ingredient-group `<div>` body contains at least one
    /// `<li class="wprm-recipe-ingredient">` line row.
    static func groupContainsLineRow(_ groupInner: String) -> Bool {
        firstElementInner(in: groupInner, tag: "li", classToken: ingredientRowToken) != nil
    }
}

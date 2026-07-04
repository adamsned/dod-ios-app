import Foundation

/// DUT-544 / DUT-554: instructions-region scoping for the "How to Make"
/// numbered-step fallback, split out of ``WPRMRecipeCardParser`` so the main
/// type stays under SwiftLint's `type_body_length` / `file_length` caps. The
/// low-level heading scan lives in ``WPRMRecipeCardParser+StepRegionScan``.
extension WPRMRecipeCardParser {

    /// Heading-text fragments that mark the start of a post's instructions /
    /// "How to Make" region. Matched case-insensitively against the plain-text
    /// of each `<h2>` / `<h3>`; the first hit anchors the region the step scan is
    /// confined to (DUT-544). DUT-554 broadened the list beyond the original six
    /// ("how to make" / "how to cook" / "how to prepare" / "instructions" /
    /// "directions" / "step-by-step") to cover the "Method" / "Preparation" /
    /// "Assembly" / "Make It" heading variants WPRM/Gutenberg posts also use.
    static let instructionsHeadingMarkers = [
        "how to make",
        "how to cook",
        "how to prepare",
        "how to assemble",
        "instructions",
        "directions",
        "step-by-step",
        "method",
        "preparation",
        "assembly",
        "make it",
        "let's make",
    ]

    /// Heading tags scanned for the instructions region. DUT-544 scanned only
    /// `<h2>`; DUT-554 adds `<h3>` because WPRM/Gutenberg posts frequently put
    /// the steps sub-heading (e.g. `<h3>Directions</h3>`) at `<h3>`.
    static let instructionsHeadingTags = ["h2", "h3"]

    /// DUT-544 fallback (scopes the DUT-538 fallback): collect step text from
    /// the `<ol class="…is-style-circle-number-list…">` lists that live inside
    /// the post's instructions / "How to Make" region ONLY — never page-wide.
    ///
    /// **Why the scope (DUT-544).** DUT-538 scanned every
    /// `is-style-circle-number-list` `<ol>` on the page, so an unrelated
    /// author-styled numbered list elsewhere in the body (a "Tips",
    /// "Substitutions", or "Variations" list that happens to use the same
    /// Gutenberg block style) was injected into the steps. We slice the page from
    /// the first heading whose text names an instructions region (see
    /// ``instructionsHeadingMarkers``) to the next heading boundary of the same
    /// level and scan only that slice. WPRM renders the "How to Make" steps as one
    /// such `<ol>` per step (each holding a single `<li>`), so flattening the
    /// `<li>` rows across the matching lists inside the region yields the ordered
    /// steps.
    ///
    /// **DUT-554 last-resort fallback.** When NO instructions heading matches but
    /// the page carries EXACTLY ONE `is-style-circle-number-list` numbered group,
    /// that lone list is used as the steps rather than returning empty — an
    /// un-anchored but unambiguous numbered list on a recipe-typed page is far
    /// more likely to be the steps than noise. When a heading DOES match we keep
    /// the region-scoping (so the DUT-544 "Tips list" pollution stays fixed);
    /// when two-or-more un-anchored lists exist we still return empty rather than
    /// guessing which is the steps.
    static func parseNumberedStepList(in page: String) -> [String] {
        if let region = instructionsRegion(in: page) {
            return numberedSteps(in: region)
        }
        return soleNumberedStepList(in: page)
    }

    /// Flatten the `<li>` rows of every `is-style-circle-number-list` `<ol>` in
    /// `html`, in document order.
    static func numberedSteps(in html: String) -> [String] {
        collectElementInners(in: html, tag: "ol", classToken: numberedStepListToken)
            .flatMap { listInner in
                collectElementTexts(
                    in: listInner,
                    tag: "li",
                    classToken: nil,
                    transform: HTMLSanitizer.plainText(from:)
                )
            }
    }

    /// DUT-554 last resort: when the page has NO instructions heading but carries
    /// exactly ONE `is-style-circle-number-list` `<ol>`, return its steps; return
    /// empty otherwise (zero lists → nothing to recover; two-or-more → ambiguous,
    /// don't guess).
    static func soleNumberedStepList(in page: String) -> [String] {
        let lists = collectElementInners(in: page, tag: "ol", classToken: numberedStepListToken)
        guard lists.count == 1, let only = lists.first else { return [] }
        return collectElementTexts(
            in: only,
            tag: "li",
            classToken: nil,
            transform: HTMLSanitizer.plainText(from:)
        )
    }
}

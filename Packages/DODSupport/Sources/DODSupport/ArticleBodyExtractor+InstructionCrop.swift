import Foundation

/// DUT-573 / CL-313 — the instruction-heading crop that removes the author's
/// inline step-by-step walkthrough from the recipe blurb (it duplicates the
/// Instructions section rendered below via AC-4.3). Split into this
/// `+`-suffixed file to keep ``ArticleBodyExtractor`` under SwiftLint's
/// `file_length` / `type_body_length` caps.
extension ArticleBodyExtractor {

    /// DUT-573 / CL-313: crop an HTML slice at the first heading
    /// (`<h1>`..`<h6>`) whose inner text (tags stripped, case-insensitive)
    /// matches an instruction-section pattern, returning only the HTML BEFORE
    /// that heading. Keeps the intro story + "why you'll love it" / tips
    /// paragraphs but drops the step-by-step walkthrough that duplicates the
    /// Instructions section (AC-4.3). Returns the input unchanged when no such
    /// heading is present.
    ///
    /// **Patterns** (matched as a case-insensitive substring of the stripped
    /// heading text): "how to make", "how to", "instructions", "directions",
    /// "step by step", "step-by-step", "steps", "method", "let's make",
    /// "how i make".
    public static func croppingBeforeInstructionHeading(_ html: String) -> String {
        var cursor = html.startIndex
        while cursor < html.endIndex {
            // Find the next heading opening tag `<h1`..`<h6`.
            guard let openTagStart = rangeOfHeadingOpenTag(in: html, from: cursor) else {
                return html
            }
            // Find the end `>` of the opening tag.
            guard
                let openTagEnd = html.range(
                    of: ">",
                    range: openTagStart.upperBound..<html.endIndex
                )
            else {
                return html
            }
            // Determine the heading level char (the digit right after `<h`) so
            // we can locate the matching close tag.
            let levelIndex = html.index(openTagStart.lowerBound, offsetBy: 2)
            let level = html[levelIndex]
            let closeTag = "</h\(level)>"
            guard
                let closeRange = html.range(
                    of: closeTag,
                    options: .caseInsensitive,
                    range: openTagEnd.upperBound..<html.endIndex
                )
            else {
                return html
            }
            let inner = html[openTagEnd.upperBound..<closeRange.lowerBound]
            if headingTextMatchesInstructionPattern(inner) {
                // Crop before the heading's opening `<h*` tag.
                return String(html[html.startIndex..<openTagStart.lowerBound])
            }
            cursor = closeRange.upperBound
        }
        return html
    }

    /// DUT-573 / CL-313: instruction-section heading patterns (lowercase).
    /// Matched as a case-insensitive substring of the tag-stripped heading text.
    static let instructionHeadingPatterns: [String] = [
        "how to make",
        "how i make",
        "how to",
        "let's make",
        "step by step",
        "step-by-step",
        "instructions",
        "directions",
        "steps",
        "method",
    ]

    /// DUT-573 / CL-313: true when the heading's inner HTML, with tags stripped,
    /// contains any ``instructionHeadingPatterns`` token (case-insensitive).
    static func headingTextMatchesInstructionPattern<S: StringProtocol>(_ innerHTML: S) -> Bool {
        // Strip any nested tags (e.g. `<span>`) from the heading text.
        var text = ""
        var insideTag = false
        for character in innerHTML {
            if character == "<" {
                insideTag = true
            } else if character == ">" {
                insideTag = false
            } else if !insideTag {
                text.append(character)
            }
        }
        let normalized = text.lowercased()
        for pattern in instructionHeadingPatterns where normalized.contains(pattern) {
            return true
        }
        return false
    }

    /// DUT-573 / CL-313: find the next `<h1`..`<h6` opening-tag prefix at or
    /// after `from`. Returns the range of the 3-char `<hN` prefix (so the
    /// caller can read the level digit and crop at `lowerBound`), or nil when
    /// no heading opening remains.
    static func rangeOfHeadingOpenTag(in html: String, from: String.Index) -> Range<String.Index>? {
        var cursor = from
        while cursor < html.endIndex {
            guard
                let ltRange = html.range(
                    of: "<h",
                    options: .caseInsensitive,
                    range: cursor..<html.endIndex
                )
            else {
                return nil
            }
            // The char after `<h` must be a level digit 1-6.
            let digitIndex = ltRange.upperBound
            guard digitIndex < html.endIndex, let level = html[digitIndex].wholeNumberValue,
                (1...6).contains(level)
            else {
                cursor = ltRange.upperBound
                continue
            }
            // Prefix range = `<hN` (from `<` through the digit inclusive).
            return ltRange.lowerBound..<html.index(after: digitIndex)
        }
        return nil
    }
}

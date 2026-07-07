import Foundation

/// A small, dependency-free decoder for the HTML entities that show up in
/// WordPress REST error messages and comment bodies.
///
/// Deliberately NOT `NSAttributedString(data:options:[.documentType: .html])`:
/// that path is slow, main-thread-only, and drags in WebKit — far too heavy
/// for cleaning a one-line snackbar string. This resolves the handful of
/// entities WordPress actually emits so a message like
/// "you&#8217;ve already said that" reads "you've already said that" instead
/// of leaking the raw entity (DUT-27).
///
/// Scope: a display cleaner for short strings, not a spec-complete SGML
/// entity resolver. Unrecognized or malformed references are left verbatim
/// rather than dropped, so text is never silently eaten.
enum HTMLEntityDecoder {

    /// Named entities decoded by hand. Covers the common punctuation set the
    /// task calls out (`&amp;` `&lt;` `&gt;` `&quot;` `&#39;` / `&apos;`
    /// `&nbsp;` `&hellip;`). `&amp;` is decoded LAST by ``decode(_:)`` so the
    /// `&` it produces cannot accidentally re-form another entity.
    private static let namedEntities: [String: String] = [
        "&lt;": "<",
        "&gt;": ">",
        "&quot;": "\"",
        "&apos;": "'",
        "&#39;": "'",
        "&#039;": "'",
        "&nbsp;": "\u{00A0}",
        "&hellip;": "\u{2026}",
    ]

    /// Decode the HTML entities in `string` into their Unicode characters.
    /// Passes, in order:
    ///
    /// 1. Numeric references — decimal `&#NNNN;` and hex `&#xHHHH;` — resolved
    ///    via the referenced Unicode scalar (e.g. `&#8217;` → `’`, the right
    ///    single quote WordPress substitutes for a typed apostrophe).
    /// 2. The common named entities in ``namedEntities``.
    /// 3. `&amp;` last, so the ampersand it stands for cannot re-form an
    ///    entity from an earlier pass; a literal `&amp;` collapses to `&`.
    /// 4. DUT-394: one more numeric+named pass, because WP REST bodies routinely
    ///    double-encode (`&amp;#8217;`). After step 3 turns that into `&#8217;`,
    ///    this second pass resolves it to `’`. This unwinds exactly ONE level of
    ///    double encoding; deeper nesting is left as-is.
    static func decode(_ string: String) -> String {
        guard string.contains("&") else { return string }
        let firstPass = resolvePass(string)
        guard firstPass.contains("&") else { return firstPass }
        return resolvePass(firstPass)
    }

    /// One full decode pass: numeric references, then the named-entity table,
    /// then `&amp;` → `&` last so the ampersand it stands for cannot re-form an
    /// entity resolved earlier in the same pass.
    private static func resolvePass(_ string: String) -> String {
        var result = decodeNumericReferences(string)
        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }

    /// Resolve `&#NNNN;` (decimal) and `&#xHHHH;` / `&#XHHHH;` (hex) numeric
    /// character references to their Unicode scalar. Unparseable or
    /// out-of-range references are left verbatim, so a stray `&#;` never
    /// silently eats surrounding text.
    private static let numericEntityRegex = try? NSRegularExpression(
        pattern: "&#[xX]?[0-9A-Fa-f]+;"
    )

    private static func decodeNumericReferences(_ string: String) -> String {
        guard
            let regex = numericEntityRegex,
            !string.isEmpty
        else { return string }

        let full = NSRange(string.startIndex..<string.endIndex, in: string)
        var output = ""
        var lastEnd = string.startIndex
        for match in regex.matches(in: string, range: full) {
            guard let matchRange = Range(match.range, in: string) else { continue }
            output += string[lastEnd..<matchRange.lowerBound]
            let token = string[matchRange]
            output += scalar(forNumericEntity: token) ?? String(token)
            lastEnd = matchRange.upperBound
        }
        output += string[lastEnd...]
        return output
    }

    /// Map a single numeric entity token (`&#8217;` or `&#x2019;`) to its
    /// character, or `nil` when the code point is invalid (so the caller
    /// keeps the original text).
    private static func scalar(forNumericEntity token: Substring) -> String? {
        // Strip the leading "&#" and trailing ";".
        var digits = token.dropFirst(2).dropLast()
        let radix: Int
        if let first = digits.first, first == "x" || first == "X" {
            digits = digits.dropFirst()
            radix = 16
        } else {
            radix = 10
        }
        guard
            let code = UInt32(digits, radix: radix),
            let scalar = Unicode.Scalar(code)
        else { return nil }
        return String(Character(scalar))
    }
}

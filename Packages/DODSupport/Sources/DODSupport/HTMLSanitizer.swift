import Foundation

/// Strips HTML tags and decodes common HTML entities, returning plain text.
/// Used to normalize WP `excerpt.rendered` (which contains `<p>...</p>` and
/// numeric entities) for display in list rows.
///
/// Not a general-purpose HTML parser — handles the narrow shape WordPress
/// produces for excerpts. Anything more complex stays in the original HTML
/// and gets rendered by a real HTML view downstream.
public enum HTMLSanitizer {

    /// Sanitize an HTML excerpt to plain text.
    ///
    /// - Strips all `<...>` tag pairs.
    /// - Decodes named entities (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`,
    ///   `&nbsp;`, `&hellip;`).
    /// - Decodes numeric entities (`&#1234;` and `&#xABCD;`).
    /// - Collapses consecutive whitespace to a single space, trims edges.
    public static func plainText(from html: String) -> String {
        // DUT-389: strip comments before tags — a comment body containing a `>`
        // (e.g. `<!-- a > b -->`) would otherwise mis-terminate at the inner
        // `>` and leak the trailing fragment into the output.
        let withoutComments = strippingComments(html)
        let withoutTags = stripTags(withoutComments)
        let withDecodedEntities = decodeEntities(withoutTags)
        return collapseWhitespace(withDecodedEntities)
    }

    /// Decode named + numeric HTML entities WITHOUT stripping tags or collapsing
    /// whitespace — used by the rich article parser to decode inline text runs.
    public static func decodingEntities(_ html: String) -> String { decodeEntities(html) }

    /// DUT-389 — remove HTML comments (`<!-- … -->`) from the input. An
    /// unterminated comment is dropped through end-of-string (matching the
    /// unterminated-`<script>` policy). Exposed so both this sanitizer and
    /// ``ArticleHTMLParser`` strip comments before scanning: a comment
    /// containing an inner `>` mis-terminates tag scanning, and one containing
    /// `<div`/`<li`/`<span` corrupts block-depth tracking (dropping or merging
    /// recipe rows).
    ///
    /// DUT-437 — `<script>`/`<style>` bodies are raw text in HTML5: a `<!--`
    /// inside one (a JS string literal, or `a<!--b`, which is valid JS) is NOT
    /// a comment open. Treat those elements as opaque — copy them through
    /// untouched — so a script's stray `<!--` can't swallow the article prose
    /// that follows it. This also makes the strip safe to run FIRST, before
    /// the entry-content slice extraction whose `<div` depth-tracking a
    /// comment would otherwise corrupt.
    public static func strippingComments(_ input: String) -> String {
        guard input.contains("<!--") else { return input }
        var output = ""
        output.reserveCapacity(input.count)
        var index = input.startIndex
        while index < input.endIndex {
            guard let open = input.range(of: "<!--", range: index..<input.endIndex) else {
                output.append(contentsOf: input[index..<input.endIndex])
                break
            }
            // DUT-437: if a raw-text element opens before this comment does,
            // copy the element through opaquely and rescan from its close.
            if let rawText = earliestRawTextElement(in: input, from: index, before: open.lowerBound) {
                output.append(contentsOf: input[index..<rawText.upperBound])
                index = rawText.upperBound
                continue
            }
            output.append(contentsOf: input[index..<open.lowerBound])
            if let closeEnd = input.range(of: "-->", range: open.upperBound..<input.endIndex) {
                index = closeEnd.upperBound
            } else {
                // Unterminated comment — drop the remainder.
                index = input.endIndex
            }
        }
        return output
    }

    /// DUT-437 — the full range (open tag through matching close tag) of the
    /// earliest `<script>`/`<style>` element that OPENS in `from..<limit`, or
    /// nil when none does. An unterminated element runs to end-of-string
    /// (mirrors `ArticleHTMLParser.removeBlock`'s policy).
    private static func earliestRawTextElement(
        in input: String,
        from: String.Index,
        before limit: String.Index
    ) -> Range<String.Index>? {
        var earliest: Range<String.Index>?
        for tag in ["script", "style"] {
            let searchRange = from..<limit
            guard let open = input.range(of: "<\(tag)", options: .caseInsensitive, range: searchRange)
            else { continue }
            let tail = open.upperBound..<input.endIndex
            let close = input.range(of: "</\(tag)>", options: .caseInsensitive, range: tail)
            let range = open.lowerBound..<(close?.upperBound ?? input.endIndex)
            if let current = earliest, current.lowerBound <= range.lowerBound { continue }
            earliest = range
        }
        return earliest
    }

    // MARK: - Steps

    private static func stripTags(_ input: String) -> String {
        var output = ""
        output.reserveCapacity(input.count)
        var insideTag = false
        for character in input {
            if character == "<" {
                insideTag = true
            } else if character == ">" {
                insideTag = false
            } else if !insideTag {
                output.append(character)
            }
        }
        return output
    }

    private static let namedEntities: [String: String] = [
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": " ",
        "hellip": "…",
        "mdash": "—",
        "ndash": "–",
        "rsquo": "\u{2019}",
        "lsquo": "\u{2018}",
        "rdquo": "\u{201D}",
        "ldquo": "\u{201C}",
        // DUT-550: WordPress/WPRM frequently emits the NAMED form of common
        // recipe entities (`&frac12;` in "1½ cups", `&deg;` in oven temps).
        // Their numeric forms (`&#189;`, `&#xBD;`) already decode, but the
        // named forms passed through raw into the highest-visibility field
        // (ingredient amounts). Decode the vulgar fractions + degree/math signs.
        "frac12": "½",
        "frac14": "¼",
        "frac34": "¾",
        "frac13": "⅓",
        "frac23": "⅔",
        "frac18": "⅛",
        "frac38": "⅜",
        "frac58": "⅝",
        "frac78": "⅞",
        "deg": "°",
        "times": "×",
        "divide": "÷",
        "middot": "·",
        "frasl": "⁄",
    ]

    /// DUT-466 (mirrors DUT-394 in `HTMLEntityDecoder`) — WP REST bodies
    /// routinely DOUBLE-encode (`&amp;#8217;`). A single left-to-right scan
    /// turns that into `&#8217;` and stops, leaving the numeric reference shown
    /// raw. Run a second scan when the first still leaves an `&`, unwinding
    /// exactly one level of double-encoding: `&amp;#8217;` → `&#8217;` → `’`
    /// and `&amp;amp;` → `&amp;` → `&`, while a lone literal `&amp;` still → `&`.
    private static func decodeEntities(_ input: String) -> String {
        guard input.contains("&") else { return input }
        let firstPass = decodeEntitiesOnce(input)
        guard firstPass.contains("&") else { return firstPass }
        return decodeEntitiesOnce(firstPass)
    }

    private static func decodeEntitiesOnce(_ input: String) -> String {
        var output = ""
        output.reserveCapacity(input.count)
        var index = input.startIndex
        while index < input.endIndex {
            let character = input[index]
            if character == "&", let semicolonIndex = input[index...].firstIndex(of: ";"), semicolonIndex > index {
                let inner = String(input[input.index(after: index)..<semicolonIndex])
                if let decoded = decodeEntity(inner) {
                    output.append(decoded)
                    index = input.index(after: semicolonIndex)
                    continue
                }
            }
            output.append(character)
            index = input.index(after: index)
        }
        return output
    }

    private static func decodeEntity(_ inner: String) -> String? {
        if inner.hasPrefix("#") {
            return decodeNumeric(inner)
        }
        return namedEntities[inner]
    }

    private static func decodeNumeric(_ inner: String) -> String? {
        let digits = inner.dropFirst()
        let scalarValue: UInt32?
        if digits.first == "x" || digits.first == "X" {
            scalarValue = UInt32(digits.dropFirst(), radix: 16)
        } else {
            scalarValue = UInt32(digits, radix: 10)
        }
        guard let value = scalarValue, let scalar = Unicode.Scalar(value) else {
            return nil
        }
        return String(Character(scalar))
    }

    private static func collapseWhitespace(_ input: String) -> String {
        let components = input.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return components.joined(separator: " ")
    }
}

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
        let withoutTags = stripTags(html)
        let withDecodedEntities = decodeEntities(withoutTags)
        return collapseWhitespace(withDecodedEntities)
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
    ]

    private static func decodeEntities(_ input: String) -> String {
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

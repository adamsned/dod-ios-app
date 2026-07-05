import DODSupport
import Foundation

/// JSON-LD mapping for the DUT-572 / CL-310 editorial info fields — Course
/// (`recipeCategory`), Cuisine (`recipeCuisine`), Diet (`suitableForDiet`), and
/// Author — plus `parseServings`. Extracted from `JSONLDRecipeParser.swift` to
/// keep that file under the file_length / type_body_length caps.
extension JSONLDRecipeParser {

    /// `recipeYield` may be a number, a string, or an array of strings.
    static func parseServings(_ raw: Any?) -> Int? {
        if let int = raw as? Int { return int }
        if let double = raw as? Double {
            // DUT-518: `Int(Double)` traps on out-of-range or non-finite input
            // (e.g. `recipeYield: 1e30` or `1e400`). Guard the range before
            // converting so untrusted scraped values return nil, not a crash.
            return Int(exactly: double.rounded())
        }
        if let string = raw as? String { return Int(string) ?? Int(string.split(separator: " ").first ?? "") }
        if let array = raw as? [String], let first = array.first { return Int(first) }
        return nil
    }

    /// Map a JSON-LD field that may be a bare `String`, a `[String]`, or an
    /// array of `{name:}` objects (`[[String: Any]]`) into a sanitized
    /// `[String]`. Used for `recipeCategory` (Course), `recipeCuisine`
    /// (Cuisine), and `suitableForDiet` (Diet). Each value is run through the
    /// same `HTMLSanitizer` plain-text path the ingredient mapper uses; empty
    /// results are dropped. Returns `[]` for absent or unrecognized shapes.
    ///
    /// `suitableForDiet` values may be schema.org URLs (e.g.
    /// `https://schema.org/LowFatDiet`) — the raw string is preserved;
    /// display-time prettifying is the UI's job (CL-310 / DUT-572).
    static func mapStringOrArray(_ raw: Any?) -> [String] {
        func sanitize(_ value: String) -> String? {
            let clean = HTMLSanitizer.plainText(from: value)
            return clean.isEmpty ? nil : clean
        }
        if let string = raw as? String {
            return sanitize(string).map { [$0] } ?? []
        }
        if let array = raw as? [Any] {
            return array.compactMap { element -> String? in
                if let string = element as? String { return sanitize(string) }
                if let dict = element as? [String: Any], let name = dict["name"] as? String {
                    return sanitize(name)
                }
                return nil
            }
        }
        return []
    }

    /// Resolve an `author` value to a display name. Schema.org authors are
    /// typically a `{"@type": "Person"/"Organization", "name": ...}` dict, but
    /// may also be an array of those (take the first named one) or a bare
    /// string. Defensive like `mapVideo` — returns nil for absent/unrecognized
    /// shapes or an empty name (CL-310 / DUT-572).
    static func mapAuthorName(_ raw: Any?) -> String? {
        func name(from dict: [String: Any]) -> String? {
            guard let value = dict["name"] as? String else { return nil }
            let clean = HTMLSanitizer.plainText(from: value)
            return clean.isEmpty ? nil : clean
        }
        if let string = raw as? String {
            let clean = HTMLSanitizer.plainText(from: string)
            return clean.isEmpty ? nil : clean
        }
        if let dict = raw as? [String: Any] {
            return name(from: dict)
        }
        if let array = raw as? [Any] {
            for element in array {
                if let string = element as? String {
                    let clean = HTMLSanitizer.plainText(from: string)
                    if !clean.isEmpty { return clean }
                } else if let dict = element as? [String: Any], let resolved = name(from: dict) {
                    return resolved
                }
            }
        }
        return nil
    }
}

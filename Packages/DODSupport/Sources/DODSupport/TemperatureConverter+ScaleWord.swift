import Foundation

extension TemperatureConverter {

    /// The exact original substring a ``ScaleWord`` was parsed from — its
    /// length is used to strip the old token off the end of the unit suffix
    /// before the converted token is appended.
    static func scaleWordOriginal(_ scaleWord: ScaleWord) -> String {
        switch scaleWord {
        case .letter(let original): original
        case .word(let original): original
        }
    }

    /// Re-spell the scale token for `target`, preserving the original's form
    /// (single letter vs spelled-out word) and letter case. `F` → `C`,
    /// `fahrenheit` → `celsius`, `Fahrenheit` → `Celsius`, `CELSIUS` →
    /// `FAHRENHEIT`.
    static func converted(_ scaleWord: ScaleWord, to target: TemperatureUnit) -> String {
        switch scaleWord {
        case .letter(let original):
            let letter = target == .fahrenheit ? "F" : "C"
            return matchCase(of: original, applyingTo: letter)
        case .word(let original):
            let word = target == .fahrenheit ? "Fahrenheit" : "Celsius"
            return matchCase(of: original, applyingTo: word)
        }
    }

    /// Apply the case *style* of `source` to `replacement`:
    /// - all-uppercase source → uppercased replacement
    /// - leading-uppercase source → capitalized replacement
    /// - otherwise → lowercased replacement
    ///
    /// `replacement` is always supplied in canonical capitalized form
    /// (`"F"`, `"Celsius"`) so the three branches cover every spelling the
    /// detector accepts.
    private static func matchCase(of source: String, applyingTo replacement: String) -> String {
        if source.count > 1, source == source.uppercased() {
            return replacement.uppercased()
        }
        if let first = source.first, first.isUppercase {
            return replacement
        }
        return replacement.lowercased()
    }
}

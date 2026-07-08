import Foundation

extension TemperatureConverter {

    /// Render one matched temperature in the target unit. When the match is
    /// already in the target unit the original source span is returned
    /// verbatim (no rounding drift, no restyling). Otherwise each value is
    /// converted + rounded and the unit suffix's scale token is swapped to
    /// the target scale while every other character of the suffix (spacing,
    /// the degree symbol, the `degrees` word) is preserved.
    static func render(_ match: Match, to target: TemperatureUnit) -> String {
        guard match.scale != scale(of: target) else {
            // Already in the requested unit — leave the span untouched.
            return source(of: match)
        }

        var rendered = ""
        for (offset, value) in match.values.enumerated() {
            if offset > 0 {
                // Reproduce the literal text that sat between this value and
                // the previous one (a range separator like "-" or " to ").
                rendered += match.separator ?? ""
            }
            if let convertedValue = convert(value.magnitude, to: target) {
                rendered += format(convertedValue)
            } else {
                // A magnitude out of Int range / non-finite — leave the whole
                // source span untouched rather than crash or emit a partial.
                return source(of: match)
            }
        }
        rendered += convertedSuffix(of: match, to: target)
        return rendered
    }

    // MARK: - Conversion + rounding

    /// Convert a single magnitude to the target unit, rounded to the nearest
    /// 5 degrees (cooking-friendly). F→C and C→F both land on a multiple of
    /// five; the round-trip is intentionally not exact.
    /// Returns `nil` when the converted value is non-finite or out of `Int`
    /// range — `Int(exactly:)` is failable (never trapping) on an arbitrary
    /// externally-sourced magnitude.
    static func convert(_ magnitude: Double, to target: TemperatureUnit) -> Int? {
        let exact: Double
        switch target {
        case .celsius: exact = (magnitude - 32) * 5 / 9
        case .fahrenheit: exact = magnitude * 9 / 5 + 32
        }
        guard !exact.isInfinite, !exact.isNaN else { return nil }
        let rounded = (exact / 5).rounded()
        return Int(exactly: rounded * 5)
    }

    /// Integer rendering — every conversion rounds to a whole multiple of
    /// five, so the output never needs a decimal point even when the source
    /// was written as `212.0`.
    private static func format(_ value: Int) -> String {
        String(value)
    }

    private static func scale(of unit: TemperatureUnit) -> Scale {
        switch unit {
        case .fahrenheit: .fahrenheit
        case .celsius: .celsius
        }
    }

    // MARK: - Source reconstruction

    /// The full original substring covered by the match — used for the
    /// already-target-unit no-op path.
    private static func source(of match: Match) -> String {
        var text = ""
        for (offset, value) in match.values.enumerated() {
            if offset > 0 { text += match.separator ?? "" }
            text += value.literal
        }
        return text + match.unitSuffix
    }

    /// The unit suffix with only its trailing scale token swapped to the
    /// target scale's spelling (case + letter/word form preserved).
    private static func convertedSuffix(of match: Match, to target: TemperatureUnit) -> String {
        let originalToken = scaleWordOriginal(match.scaleWord)
        let keep = String(match.unitSuffix.dropLast(originalToken.count))
        return keep + converted(match.scaleWord, to: target)
    }
}

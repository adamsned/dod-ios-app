import Foundation

/// Extracts a cook duration from a free-text recipe instruction (e.g. the
/// `text` field of ``RecipeInstruction``) so Cook Mode can offer an inline
/// timer for the step.
///
/// Spec trace: US-7 (Cook Mode), inline timer requirement on the displayed
/// step. The parser is conservative — it never invents a duration. If a step
/// reads "Preheat the oven to 350°F" it returns `nil` rather than picking up
/// the "350" as 350 of something.
///
/// Supported phrasings (case-insensitive):
/// - "Bake for 30 minutes" → 1800s
/// - "Simmer for 1 hour 30 minutes" → 5400s (mixed units)
/// - "Rest 1 1/2 hours" → 5400s (ASCII fraction)
/// - "Cook 1.5 hours" → 5400s (decimal)
/// - "Whisk for 45 seconds" / "45 sec" → 45s
/// - "Steep for ½ hour" → 1800s (Unicode vulgar fraction)
///
/// Out of scope (returns `nil`):
/// - Word numerals: "ten minutes", "half an hour"
/// - Time-of-day or temperatures: "350°F"
/// - Bare numbers with no unit: "stir 3 times"
public enum StepTimerParser {

    /// First plausible cook duration discovered in `text`, or `nil`.
    public static func firstDuration(in text: String) -> Duration? {
        // Walk the string looking for the first `<quantity><unit>` pair.
        // Once found, peek one token to the right for a smaller-unit
        // follow-up so "1 hour 30 minutes" lands as 5400s.
        guard let primary = nextQuantityUnit(in: text, from: text.startIndex) else {
            return nil
        }
        // DUT-914: `RecipeInstruction.text` is untrusted JSON-LD; a malformed
        // 20+ digit quantity makes `quantity × seconds` exceed `Int.max`, and a
        // trapping `Int(Double)` would crash Cook Mode (same class as
        // FractionRenderer's DUT-609). An absurd multi-billion-second value is
        // not a usable timer, so bail to nil via the guarded `safeSeconds`.
        guard let baseSeconds = safeSeconds(primary.quantity, primary.unit) else { return nil }
        let mixedExtra = mixedFollowUp(in: text, from: primary.afterIndex, currentUnit: primary.unit)
        let total = baseSeconds + mixedExtra
        return total > 0 ? .seconds(total) : nil
    }

    /// Whole seconds for `quantity × unit.seconds`, or `nil` when the product is
    /// non-finite or overflows `Int` (DUT-914 — untrusted JSON-LD can carry a
    /// pathological digit run; a bare `Int(Double)` traps on overflow).
    private static func safeSeconds(_ quantity: Double, _ unit: Unit) -> Int? {
        let product = (quantity * Double(unit.seconds)).rounded()
        guard product.isFinite else { return nil }
        return Int(exactly: product)
    }

    // MARK: - Internals

    /// A duration unit we recognize. Listed shortest first so the longer
    /// spellings (e.g. "hours") win over "h".
    private enum Unit {
        case hours, minutes, seconds

        var seconds: Int {
            switch self {
            case .hours: 3600
            case .minutes: 60
            case .seconds: 1
            }
        }

        static let alternatives: [(token: String, unit: Unit)] = [
            ("hours", .hours), ("hour", .hours), ("hrs", .hours), ("hr", .hours),
            ("minutes", .minutes), ("minute", .minutes), ("mins", .minutes), ("min", .minutes),
            ("seconds", .seconds), ("second", .seconds), ("secs", .seconds), ("sec", .seconds),
        ]
    }

    /// One quantity-with-unit hit. Pulled out of a tuple to satisfy the
    /// large-tuple lint rule (no more than 2 members per tuple).
    private struct QuantityUnit {
        let quantity: Double
        let unit: Unit
        let afterIndex: String.Index
    }

    /// One numeric quantity scan result.
    private struct Quantity {
        let value: Double
        let after: String.Index
    }

    /// One unit-token scan result.
    private struct UnitMatch {
        let unit: Unit
        let after: String.Index
    }

    /// Scan from `index` for the next `<quantity><whitespace>?<unit>` pair.
    /// Returns `nil` when the string is exhausted with no hit.
    private static func nextQuantityUnit(
        in text: String,
        from index: String.Index
    ) -> QuantityUnit? {
        var cursor = index
        while cursor < text.endIndex {
            if let quantity = readQuantity(in: text, from: cursor) {
                let afterSpace = skipWhitespace(in: text, from: quantity.after)
                if let unit = readUnit(in: text, from: afterSpace) {
                    return QuantityUnit(quantity: quantity.value, unit: unit.unit, afterIndex: unit.after)
                }
                cursor = quantity.after
                continue
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    /// Looks one quantity+unit pair past `index`. If the next unit is strictly
    /// smaller than `currentUnit`, returns its seconds contribution.
    private static func mixedFollowUp(
        in text: String,
        from index: String.Index,
        currentUnit: Unit
    ) -> Int {
        let skipped = skipWhitespaceAndGlue(in: text, from: index)
        // DUT-248: the mixed follow-up must begin IMMEDIATELY after the glue (e.g.
        // "1 hour 30 minutes"), not after intervening words — "1 hour, then rest 30
        // minutes" must stay 1 hour. `nextQuantityUnit` scans arbitrarily far, so
        // require a numeric quantity right at the glue-skipped index.
        guard skipped < text.endIndex, text[skipped].isNumber else { return 0 }
        guard let next = nextQuantityUnit(in: text, from: skipped) else { return 0 }
        guard next.unit.seconds < currentUnit.seconds else { return 0 }
        // DUT-914: guard the same Int-overflow trap as the primary path; an
        // overflowing follow-up simply contributes nothing.
        return safeSeconds(next.quantity, next.unit) ?? 0
    }

    /// Read one numeric quantity starting at `index`. Dispatches to the
    /// shape-specific helpers so the cyclomatic complexity stays bounded.
    private static func readQuantity(in text: String, from index: String.Index) -> Quantity? {
        if let single = text[index...].first, let value = vulgarFraction(single) {
            return Quantity(value: value, after: text.index(after: index))
        }
        guard let firstChar = text[index...].first, firstChar.isNumber else { return nil }
        let wholeRange = scanInteger(in: text, from: index)
        let whole = Double(text[index..<wholeRange]) ?? 0

        if let decimal = readDecimalSuffix(in: text, wholeStart: index, after: wholeRange) {
            return decimal
        }
        if let attached = readAttachedFraction(in: text, whole: whole, after: wholeRange) {
            return attached
        }
        if let mixed = readMixedNumberSuffix(in: text, whole: whole, after: wholeRange) {
            return mixed
        }
        return Quantity(value: whole, after: wholeRange)
    }

    /// Read consecutive digits, returning the end index.
    private static func scanInteger(in text: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < text.endIndex, text[cursor].isNumber {
            cursor = text.index(after: cursor)
        }
        return cursor
    }

    /// "1.5" → 1.5. Returns nil if there's no decimal point at `after`.
    private static func readDecimalSuffix(
        in text: String,
        wholeStart: String.Index,
        after: String.Index
    ) -> Quantity? {
        guard after < text.endIndex, text[after] == "." else { return nil }
        let afterDot = text.index(after: after)
        let endIndex = scanInteger(in: text, from: afterDot)
        guard endIndex > afterDot, let combined = Double(text[wholeStart..<endIndex]) else {
            return nil
        }
        return Quantity(value: combined, after: endIndex)
    }

    /// "1/2" (attached, no whitespace). Returns nil if no slash follows.
    private static func readAttachedFraction(
        in text: String,
        whole: Double,
        after: String.Index
    ) -> Quantity? {
        guard after < text.endIndex, text[after] == "/" else { return nil }
        let denomStart = text.index(after: after)
        let denomEnd = scanInteger(in: text, from: denomStart)
        guard denomEnd > denomStart,
            let denominator = Double(text[denomStart..<denomEnd]),
            denominator > 0
        else { return nil }
        return Quantity(value: whole / denominator, after: denomEnd)
    }

    /// "1 1/2" or "1 ½" — whole number, whitespace, then a fraction.
    private static func readMixedNumberSuffix(
        in text: String,
        whole: Double,
        after: String.Index
    ) -> Quantity? {
        let afterSpace = skipWhitespace(in: text, from: after)
        guard afterSpace != after else { return nil }
        if let unicodeFrac = text[afterSpace...].first, let fracValue = vulgarFraction(unicodeFrac) {
            return Quantity(value: whole + fracValue, after: text.index(after: afterSpace))
        }
        return readAsciiMixedTail(in: text, whole: whole, fractionStart: afterSpace)
    }

    /// "<whole> N/D" tail. Returns nil if no slash-fraction follows.
    private static func readAsciiMixedTail(
        in text: String,
        whole: Double,
        fractionStart: String.Index
    ) -> Quantity? {
        guard let firstChar = text[fractionStart...].first, firstChar.isNumber else { return nil }
        let numEnd = scanInteger(in: text, from: fractionStart)
        guard numEnd < text.endIndex, text[numEnd] == "/" else { return nil }
        let denomStart = text.index(after: numEnd)
        let denomEnd = scanInteger(in: text, from: denomStart)
        guard denomEnd > denomStart,
            let numerator = Double(text[fractionStart..<numEnd]),
            let denominator = Double(text[denomStart..<denomEnd]),
            denominator > 0
        else { return nil }
        return Quantity(value: whole + numerator / denominator, after: denomEnd)
    }

    private static func vulgarFraction(_ character: Character) -> Double? {
        Self.vulgarFractions[character]
    }

    private static let vulgarFractions: [Character: Double] = [
        "½": 0.5,
        "⅓": 1.0 / 3.0,
        "⅔": 2.0 / 3.0,
        "¼": 0.25,
        "¾": 0.75,
        "⅕": 0.2,
        "⅖": 0.4,
        "⅗": 0.6,
        "⅘": 0.8,
        "⅙": 1.0 / 6.0,
        "⅚": 5.0 / 6.0,
        "⅛": 0.125,
        "⅜": 0.375,
        "⅝": 0.625,
        "⅞": 0.875,
    ]

    /// Read a unit token starting at `index`. Matching is case-insensitive
    /// and the token must end on a non-letter boundary so "second" doesn't
    /// match "seconds" prematurely.
    private static func readUnit(in text: String, from index: String.Index) -> UnitMatch? {
        let lower = String(text[index...]).lowercased()
        for (token, unit) in Unit.alternatives where lower.hasPrefix(token) {
            let endIndex = lower.index(lower.startIndex, offsetBy: token.count)
            if endIndex < lower.endIndex, lower[endIndex].isLetter {
                continue
            }
            return UnitMatch(unit: unit, after: text.index(index, offsetBy: token.count))
        }
        return nil
    }

    private static func skipWhitespace(in text: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
        return cursor
    }

    /// Skip whitespace plus an optional "and" / "," glue word between mixed
    /// units (e.g. "1 hour and 30 minutes").
    private static func skipWhitespaceAndGlue(in text: String, from index: String.Index) -> String.Index {
        var cursor = skipWhitespace(in: text, from: index)
        let remaining = text[cursor...].lowercased()
        if remaining.hasPrefix("and ") {
            cursor = text.index(cursor, offsetBy: 4)
            cursor = skipWhitespace(in: text, from: cursor)
        } else if remaining.hasPrefix(", ") {
            cursor = text.index(cursor, offsetBy: 2)
            cursor = skipWhitespace(in: text, from: cursor)
        }
        return cursor
    }
}

import Foundation

/// One recipe-ingredient line parsed into its `(quantity, unit, name)` parts.
///
/// Produced by ``IngredientLineParser`` and consumed by
/// ``IngredientAggregator``. A line with no recoverable leading quantity has
/// all-`nil` numeric fields and is treated as unmergeable verbatim text.
/// Exposed `public` (DUT-517) so the imperial→metric converter in
/// ``IngredientMetricConverter`` can reuse the same leading-quantity + unit
/// scan the aggregator relies on, instead of replicating it.
public struct ParsedIngredientLine {
    /// The verbatim input (the display text + classify source when no quantity
    /// was parsed).
    public let originalText: String
    /// Leading quantity, or `nil` when none was found.
    public let quantity: Double?
    /// Normalized singular unit (`"cup"`), or `nil`.
    public let unit: String?
    /// Whitespace-collapsed ingredient name (original case), or `nil` when no
    /// quantity/name structure was recoverable.
    public let name: String?

    /// What the aisle classifier should look at: the parsed name when we have
    /// one, otherwise the whole original line.
    var matchSource: String { name ?? originalText }
}

/// Parses a raw ingredient line into a ``ParsedIngredientLine``.
///
/// Recognizes a leading quantity (mixed number, decimal, ASCII or Unicode
/// fraction, or plain integer) optionally followed by a known unit token; the
/// remainder is the name (a leading `"of "` is dropped, whitespace collapsed).
///
/// Spec trace: US-39 / AC-39.4 + AC-39.7 (the substrate ``IngredientAggregator``
/// merges on). CL-70 + CL-80. The unit list + vulgar-fraction table mirror the
/// CL-67 tokenizer regex and ``FractionRenderer`` so the parsers agree.
public enum IngredientLineParser {

    /// Parse a raw ingredient line.
    public static func parse(_ text: String) -> ParsedIngredientLine {
        let unparseable = ParsedIngredientLine(
            originalText: text,
            quantity: nil,
            unit: nil,
            name: nil
        )
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let (quantity, afterQuantity) = readLeadingQuantity(trimmed) else {
            return unparseable
        }
        let afterQuantityText = trimmed[afterQuantity...].trimmingCharacters(in: .whitespaces)
        // DUT-667: drop a leading parenthetical size annotation before the
        // unit/name scan, e.g. `"1 (14 oz) can black beans"` → scan
        // `"can black beans"` so the unit reads `can` and the name `black
        // beans`, not a bogus `(14` unit-word. Only a leading `(…)` is
        // stripped; parentheticals later in the line are left in the name.
        let remainder = strippingLeadingParenthetical(afterQuantityText)
        let (unit, nameStart) = readUnit(remainder)
        // A quantity with an empty trailing name (e.g. the line was just "2")
        // isn't a useful shopping item — fall back to verbatim.
        guard let name = normalizeName(String(remainder[nameStart...])) else {
            return unparseable
        }
        return ParsedIngredientLine(
            originalText: text,
            quantity: quantity,
            unit: unit,
            name: name
        )
    }

    /// DUT-913 — like ``parse(_:)`` but keeps a recovered `(quantity, unit)`
    /// even when NO ingredient name follows (e.g. a bare `"2 cups"`).
    /// ``parse(_:)`` deliberately returns all-`nil` for a nameless line because
    /// the shopping-list ``IngredientAggregator`` treats it as unmergeable
    /// verbatim text — but ``IngredientMetricConverter`` still wants to convert
    /// `"2 cups"` → `"480 ml"`. This shares the exact same leading-quantity +
    /// unit scan and simply drops the name requirement. `parse(_:)` and the
    /// aggregator are untouched.
    public static func parseQuantityAndUnit(_ text: String) -> (quantity: Double, unit: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let (quantity, afterQuantity) = readLeadingQuantity(trimmed) else { return nil }
        let afterQuantityText = trimmed[afterQuantity...].trimmingCharacters(in: .whitespaces)
        let remainder = strippingLeadingParenthetical(afterQuantityText)
        let (unit, _) = readUnit(remainder)
        guard let unit else { return nil }
        return (quantity, unit)
    }

    // MARK: - Quantity

    /// Read a leading numeric quantity. Returns the value and the index just
    /// past it, or `nil` if the line doesn't start with a number or fraction.
    private static func readLeadingQuantity(_ text: String) -> (Double, String.Index)? {
        guard let first = text.first else { return nil }
        // Unicode vulgar fraction as the very first character: "½ cup".
        if let fraction = vulgarFractions[first] {
            return (fraction, text.index(after: text.startIndex))
        }
        guard first.isNumber else { return nil }

        let wholeEnd = scanDigits(text, from: text.startIndex)
        let whole = Double(text[text.startIndex..<wholeEnd]) ?? 0
        if let decimal = readDecimalTail(text, wholeStart: text.startIndex, dotCandidate: wholeEnd) {
            return decimal
        }
        if let attached = readSlashFraction(text, numeratorStart: text.startIndex, slashAt: wholeEnd) {
            return attached
        }
        // Glued vulgar fraction with no space: `"1½"` (DUT-393). The ASCII digit
        // scan stops before the glyph, so it sits directly at `wholeEnd`.
        if wholeEnd < text.endIndex, let glyph = vulgarFractions[text[wholeEnd]] {
            return (whole + glyph, text.index(after: wholeEnd))
        }
        if let mixed = readMixedTail(text, whole: whole, afterWhole: wholeEnd) {
            return mixed
        }
        return (whole, wholeEnd)  // Plain integer.
    }

    /// Decimal form: `"1.5"`. `dotCandidate` is the index just past the whole
    /// digits (where a `.` would sit).
    private static func readDecimalTail(
        _ text: String,
        wholeStart: String.Index,
        dotCandidate: String.Index
    ) -> (Double, String.Index)? {
        guard dotCandidate < text.endIndex, text[dotCandidate] == "." else { return nil }
        let fracStart = text.index(after: dotCandidate)
        let fracEnd = scanDigits(text, from: fracStart)
        guard fracEnd > fracStart, let value = Double(text[wholeStart..<fracEnd]) else { return nil }
        return (value, fracEnd)
    }

    /// Mixed number: whole + space + (vulgar | slash) fraction, e.g. `"1 ½"`
    /// or `"1 1/2"`. `afterWhole` is the index just past the whole digits.
    private static func readMixedTail(
        _ text: String,
        whole: Double,
        afterWhole: String.Index
    ) -> (Double, String.Index)? {
        let afterSpace = skipSpaces(text, from: afterWhole)
        guard afterSpace > afterWhole, afterSpace < text.endIndex else { return nil }
        if let glyph = vulgarFractions[text[afterSpace]] {
            return (whole + glyph, text.index(after: afterSpace))
        }
        guard text[afterSpace].isNumber else { return nil }
        let numEnd = scanDigits(text, from: afterSpace)
        guard let (frac, end) = readSlashFraction(text, numeratorStart: afterSpace, slashAt: numEnd)
        else { return nil }
        return (whole + frac, end)
    }

    /// Read a `numerator/denominator` fraction. `slashAt` must be the index of
    /// the `/`; `numeratorStart` is where the numerator's digits begin.
    private static func readSlashFraction(
        _ text: String,
        numeratorStart: String.Index,
        slashAt: String.Index
    ) -> (Double, String.Index)? {
        guard slashAt < text.endIndex, text[slashAt] == "/" else { return nil }
        let denomStart = text.index(after: slashAt)
        let denomEnd = scanDigits(text, from: denomStart)
        guard denomEnd > denomStart,
            let numerator = Double(text[numeratorStart..<slashAt]),
            let denominator = Double(text[denomStart..<denomEnd]),
            denominator > 0
        else { return nil }
        return (numerator / denominator, denomEnd)
    }

    // MARK: - Unit + name

    /// Drop a single leading `(…)` parenthetical from `text` (DUT-667 — a size
    /// annotation like `"(14 oz)"` between the quantity and the unit). Returns
    /// the whitespace-trimmed remainder after the matching `)`. When the text
    /// doesn't start with `(`, or the `(` is unterminated, the text is returned
    /// trimmed and unchanged.
    private static func strippingLeadingParenthetical(_ text: String) -> String {
        guard text.first == "(" else { return text }
        guard let close = text.firstIndex(of: ")") else { return text }
        let after = text[text.index(after: close)...]
        return after.trimmingCharacters(in: .whitespaces)
    }

    /// If `text` begins with a known unit token, return its normalized singular
    /// form and the index where the name begins; otherwise `nil` unit and the
    /// original start (the whole remainder is the name).
    private static func readUnit(_ text: String) -> (String?, String.Index) {
        let wordEnd = text.firstIndex(where: { $0 == " " }) ?? text.endIndex
        let firstWord = text[text.startIndex..<wordEnd]
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        guard let canonical = unitAliases[firstWord] else {
            return (nil, text.startIndex)
        }
        return (canonical, skipSpaces(text, from: wordEnd))
    }

    /// Collapse internal whitespace + drop a leading `"of "`. Returns `nil` for
    /// an empty result.
    private static func normalizeName(_ raw: String) -> String? {
        var working = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if working.lowercased().hasPrefix("of ") {
            working = String(working.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
        let collapsed =
            working
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }

    // MARK: - Scanning

    /// Scan a run of ASCII digits. DUT-393: `Character.isNumber` is `true` for
    /// vulgar fractions (`½`, `¼`, …), so an unrestricted scan would swallow the
    /// glyph in a glued `"1½"` and yield `Double("1½") == nil → 0`. Restricting
    /// to ASCII leaves the glued fraction for the mixed/attached-tail logic to
    /// pick up.
    private static func scanDigits(_ text: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < text.endIndex, text[cursor].isASCII, text[cursor].isNumber {
            cursor = text.index(after: cursor)
        }
        return cursor
    }

    private static func skipSpaces(_ text: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < text.endIndex, text[cursor] == " " {
            cursor = text.index(after: cursor)
        }
        return cursor
    }

    // MARK: - Tables

    /// Maps every unit spelling/abbreviation we recognize to a canonical
    /// singular key, so `"cups"` and `"cup"` (and `"c"`) merge.
    private static let unitAliases: [String: String] = [
        "cup": "cup", "cups": "cup", "c": "cup",
        "tablespoon": "tablespoon", "tablespoons": "tablespoon",
        "tbsp": "tablespoon", "tbsps": "tablespoon", "tbs": "tablespoon", "tb": "tablespoon",
        "teaspoon": "teaspoon", "teaspoons": "teaspoon",
        "tsp": "teaspoon", "tsps": "teaspoon",
        "pound": "pound", "pounds": "pound", "lb": "pound", "lbs": "pound",
        "ounce": "ounce", "ounces": "ounce", "oz": "ounce",
        "gram": "gram", "grams": "gram", "g": "gram",
        "kilogram": "kilogram", "kilograms": "kilogram", "kg": "kilogram",
        "milliliter": "milliliter", "milliliters": "milliliter", "ml": "milliliter",
        "liter": "liter", "liters": "liter", "l": "liter",
        "clove": "clove", "cloves": "clove",
        "can": "can", "cans": "can",
        "package": "package", "packages": "package", "pkg": "package", "pkgs": "package",
        "sprig": "sprig", "sprigs": "sprig",
        "stick": "stick", "sticks": "stick",
        "slice": "slice", "slices": "slice",
        "pinch": "pinch", "pinches": "pinch",
        "quart": "quart", "quarts": "quart", "qt": "quart",
        "pint": "pint", "pints": "pint", "pt": "pint",
    ]

    /// Unicode vulgar fractions a leading quantity may use directly. Mirrors
    /// ``FractionRenderer`` and ``StepTimerParser`` so the parsers agree.
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
}

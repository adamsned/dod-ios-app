import Foundation

/// Scales a recipe-ingredient line by a multiplier and rewrites the leading
/// quantity as a cook-friendly fraction.
///
/// Spec trace: US-31 / AC-31.* (recipe scaling), CL-52 (fraction-rendering
/// precision + canonical fraction set + warning threshold). Constitution §6
/// L1 mandate (every domain transform has a unit-test home).
///
/// **Why this is its own utility:** the scaling math is pure (no recipe
/// model knowledge, no view dependencies) and the fraction-rounding tables
/// only make sense if every call site picks the same set — golden L1 tests
/// pin the table here once, not five times across feature packages.
///
/// **Cook-friendly precision (CL-52):** quantities snap to the closest
/// value in the canonical fraction set
/// `{ 1/8, 1/4, 1/3, 1/2, 2/3, 3/4, 7/8 }` plus whole numbers. The set is
/// what cooks actually measure with — `0.75` becomes `¾`, `0.333…` becomes
/// `⅓`, `1.5` becomes `1 ½`. Two of the JSON-LD fixtures already in the
/// repo use exactly this vocabulary (`1 1/2 pounds`, `2/3 cup`).
///
/// **Pure presentation:** the source `Recipe` model is never mutated. Each
/// call to ``scale(_:by:)`` produces a fresh string; the original ingredient
/// text stays untouched.
public enum FractionRenderer {

    /// Re-renders `ingredientText` with its leading quantity multiplied by
    /// `factor`. If no leading quantity is found, the text is returned
    /// verbatim — "Salt and freshly ground black pepper" never gets a
    /// quantity prefixed onto it by mistake.
    ///
    /// - Parameters:
    ///   - ingredientText: One line from `RecipeIngredient.text`.
    ///   - factor: Scaling multiplier (e.g. `userServings / sourceServings`).
    /// - Returns: The rewritten ingredient line.
    public static func scale(_ ingredientText: String, by factor: Double) -> String {
        guard factor > 0, factor.isFinite else { return ingredientText }
        guard factor != 1.0 else { return ingredientText }
        guard let parsed = parseLeadingQuantity(in: ingredientText) else {
            return ingredientText
        }
        let scaledValue = parsed.value * factor
        let rendered = renderQuantity(scaledValue)
        let trailing = ingredientText[parsed.afterIndex...]
        // DUT-304: a RANGE ingredient ("2-3 cloves", "1½–2 cups") carries a
        // second quantity behind a range separator. Scale that upper bound
        // too and re-emit "lo<sep>hi" — otherwise only the lower bound scales
        // ("4-3 cloves" nonsense). If the trailing slice isn't a range
        // continuation, fall through to the plain single-quantity rewrite.
        if let range = scaleRangeContinuation(in: trailing, by: factor) {
            // `parseLeadingQuantity` may have swallowed one space between the
            // low bound and the separator ("1 - 2" → trailing "- 2"); re-add
            // it so a spaced range keeps its spacing ("3 - 6", not "3- 6").
            let gap = consumedSpaceBeforeTrailing(in: ingredientText, at: parsed.afterIndex)
            return rendered + gap + range.separator + range.renderedHigh + range.rest
        }
        // `parseLeadingQuantity` consumes one trailing space so the rewrite
        // glues `<rendered> <trailing>` with a single space — re-add it
        // here unless the trailing slice is empty (quantity-only input).
        if trailing.isEmpty { return rendered }
        return rendered + " " + trailing
    }

    /// Renders a positive numeric quantity as a cook-friendly string.
    /// Public so tests and other call sites can pin the table directly.
    ///
    /// - Whole numbers render bare (`1`, not `1.0`).
    /// - Pure fractions render as their Unicode vulgar glyph (`½`, `⅓`).
    /// - Mixed numbers render as `<whole> <fraction>` (`2 ½`).
    /// - Sub-snap-tolerance values where the whole part is also zero
    ///   (e.g. `0.04`) fall back to two-decimal rendering — these are rare
    ///   because the canonical set's tolerance band covers everything from
    ///   `1/16` upward, so only tiny quantities round through this branch.
    public static func renderQuantity(_ value: Double) -> String {
        guard value > 0, value.isFinite else { return "0" }
        // Snap to nearest canonical fraction (eighth-cup precision).
        let whole = floor(value)
        let remainder = value - whole

        // Remainder approaches 1 within tolerance → bump to next whole.
        if remainder > (1.0 - snapTolerance) {
            return String(Int(whole + 1))
        }
        if let fraction = nearestCanonicalFraction(remainder) {
            return formatMixed(whole: whole, fractionGlyph: fraction.glyph)
        }
        // Sub-tolerance remainder + non-zero whole → render the integer.
        // "1.04 tablespoons" is noise; "1 tablespoon" is what a cook reads.
        if whole >= 1 {
            return String(Int(whole))
        }
        // Sub-tolerance remainder + zero whole → fallback to decimal.
        // Quantities this small (e.g. 0.04 tsp) are vanishingly rare on a
        // post-multiplication line; emit the literal value rather than
        // pretending it's a fraction.
        let formatter = Self.fallbackFormatter
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    // MARK: - Internals

    /// One parse hit on the head of an ingredient string.
    /// `internal` (not `private`) so the range-scaling extension in
    /// `FractionRenderer+Range.swift` (DUT-304) can read parse hits.
    struct Quantity {
        let value: Double
        let afterIndex: String.Index
    }

    /// Canonical cook-friendly fractions. Listed in numeric order so the
    /// nearest-match search is deterministic on equidistant ties.
    private struct CanonicalFraction {
        let value: Double
        let glyph: String
    }

    /// Snap-to-set per CL-52. `0` (handled inline) → "" (whole only); `1` is
    /// implicit (the integer increment).
    private static let canonical: [CanonicalFraction] = [
        .init(value: 1.0 / 8.0, glyph: "⅛"),
        .init(value: 1.0 / 4.0, glyph: "¼"),
        .init(value: 1.0 / 3.0, glyph: "⅓"),
        .init(value: 1.0 / 2.0, glyph: "½"),
        .init(value: 2.0 / 3.0, glyph: "⅔"),
        .init(value: 3.0 / 4.0, glyph: "¾"),
        .init(value: 7.0 / 8.0, glyph: "⅞"),
    ]

    /// Snap-distance tolerance. 1/16 = 0.0625 is the cook-grade neighbor
    /// half-distance between 1/8 increments — anything within this band of
    /// a canonical fraction snaps to it. Values outside (e.g. 0.13, which
    /// is more than 1/16 away from 1/8 = 0.125 by 0.005 only) still snap
    /// thanks to the linear search, but values like 0.05 — too small to
    /// be 1/8, too big to be 0 — fall through to the decimal fallback.
    private static let snapTolerance: Double = 0.0625

    /// Two-decimal fallback formatter for values that don't snap (rare —
    /// most scaled cook quantities land cleanly on the canonical set).
    /// DUT-320: this is a DISPLAY formatter, so it stays locale-aware — no
    /// pinned `en_US_POSIX`. A comma-decimal-locale cook reads "1,5", not the
    /// POSIX "1.5". (`en_US_POSIX` is reserved for PARSING stability, which
    /// `Double(_:)` already provides for the parse path above.)
    private static let fallbackFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Find the closest canonical fraction to `remainder`, or `nil` if
    /// nothing in the set is within ``snapTolerance``. Callers handle
    /// out-of-band remainders (sub-tolerance → render whole-only;
    /// approaches-1 → bump to next whole).
    private static func nearestCanonicalFraction(_ remainder: Double) -> CanonicalFraction? {
        var best: (fraction: CanonicalFraction, distance: Double)?
        for candidate in canonical {
            let distance = abs(candidate.value - remainder)
            if let current = best, current.distance <= distance { continue }
            best = (candidate, distance)
        }
        guard let best, best.distance <= snapTolerance else { return nil }
        return best.fraction
    }

    /// Compose whole + fraction glyph into a display string.
    private static func formatMixed(whole: Double, fractionGlyph: String) -> String {
        let wholeInt = Int(whole)
        // `formatMixed` is only reached after `nearestCanonicalFraction`
        // returned a snap (i.e. remainder ≥ snapTolerance), so we always
        // render the fraction glyph.
        if wholeInt == 0 { return fractionGlyph }
        return "\(wholeInt) \(fractionGlyph)"
    }

    /// Parse a numeric quantity off the head of `text`. Recognizes
    /// (in scan order):
    /// - Mixed number: `"1 1/2"`, `"2 ½"`
    /// - Decimal: `"1.5"`
    /// - Plain fraction (Unicode): `"½"`
    /// - Plain fraction (ASCII): `"1/2"`
    /// - Plain integer: `"4"`
    /// Returns the index *after* the quantity (and one trailing space if
    /// present) so callers can append the rest of the ingredient line.
    /// `internal` (not `private`) so the range-scaling extension in
    /// `FractionRenderer+Range.swift` (DUT-304) can parse the upper bound.
    static func parseLeadingQuantity(in text: String) -> Quantity? {
        guard !text.isEmpty else { return nil }
        // Try in precedence order — mixed > decimal > fraction > integer —
        // so "1 1/2 cup" doesn't parse as just "1".
        if let mixed = readMixedNumber(in: text) { return mixed }
        if let decimal = readDecimal(in: text) { return decimal }
        if let fraction = readFraction(in: text) { return fraction }
        if let integer = readInteger(in: text) { return integer }
        return nil
    }

    private static func readMixedNumber(in text: String) -> Quantity? {
        // Whole digit run.
        guard let firstChar = text.first, firstChar.isNumber else { return nil }
        let wholeEnd = scanInteger(in: text, from: text.startIndex)
        guard wholeEnd > text.startIndex else { return nil }
        let whole = Double(text[text.startIndex..<wholeEnd]) ?? 0
        // Whitespace between the whole part and the fraction is normally required
        // ("1 1/2"), but the GLUED unicode form ("1½") is unambiguous and common in
        // WP sources (DUT-351), so allow a unicode-fraction tail with no space.
        let afterSpace = skipWhitespace(in: text, from: wholeEnd)
        if afterSpace == wholeEnd {
            // No space: only a glued unicode fraction qualifies ("1½"). An ASCII run
            // like "11/2" is the fraction 11/2, not a mixed number — leave it.
            return readUnicodeFractionTail(
                in: text,
                whole: whole,
                fractionStart: wholeEnd
            )
        }
        // Followed by a Unicode-glyph fraction or an ASCII N/D pair.
        if let unicodeQuantity = readUnicodeFractionTail(
            in: text,
            whole: whole,
            fractionStart: afterSpace
        ) {
            return unicodeQuantity
        }
        return readAsciiFractionTail(in: text, whole: whole, fractionStart: afterSpace)
    }

    private static func readUnicodeFractionTail(
        in text: String,
        whole: Double,
        fractionStart: String.Index
    ) -> Quantity? {
        guard let firstChar = text[fractionStart...].first,
            let fracValue = Self.unicodeFractionValues[firstChar]
        else {
            return nil
        }
        let after = consumeSingleTrailingSpace(
            in: text,
            from: text.index(after: fractionStart)
        )
        return Quantity(value: whole + fracValue, afterIndex: after)
    }

    private static func readAsciiFractionTail(
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
        let after = consumeSingleTrailingSpace(in: text, from: denomEnd)
        return Quantity(value: whole + numerator / denominator, afterIndex: after)
    }

    private static func readDecimal(in text: String) -> Quantity? {
        guard let firstChar = text.first, firstChar.isNumber else { return nil }
        let wholeEnd = scanInteger(in: text, from: text.startIndex)
        guard wholeEnd < text.endIndex, text[wholeEnd] == "." else { return nil }
        let fracStart = text.index(after: wholeEnd)
        let fracEnd = scanInteger(in: text, from: fracStart)
        guard fracEnd > fracStart, let value = Double(text[text.startIndex..<fracEnd]) else {
            return nil
        }
        let after = consumeSingleTrailingSpace(in: text, from: fracEnd)
        return Quantity(value: value, afterIndex: after)
    }

    private static func readFraction(in text: String) -> Quantity? {
        if let first = text.first, let fracValue = Self.unicodeFractionValues[first] {
            let after = consumeSingleTrailingSpace(in: text, from: text.index(after: text.startIndex))
            return Quantity(value: fracValue, afterIndex: after)
        }
        guard let firstChar = text.first, firstChar.isNumber else { return nil }
        let numEnd = scanInteger(in: text, from: text.startIndex)
        guard numEnd < text.endIndex, text[numEnd] == "/" else { return nil }
        let denomStart = text.index(after: numEnd)
        let denomEnd = scanInteger(in: text, from: denomStart)
        guard denomEnd > denomStart,
            let numerator = Double(text[text.startIndex..<numEnd]),
            let denominator = Double(text[denomStart..<denomEnd]),
            denominator > 0
        else { return nil }
        let after = consumeSingleTrailingSpace(in: text, from: denomEnd)
        return Quantity(value: numerator / denominator, afterIndex: after)
    }

    private static func readInteger(in text: String) -> Quantity? {
        guard let firstChar = text.first, firstChar.isNumber else { return nil }
        let end = scanInteger(in: text, from: text.startIndex)
        guard end > text.startIndex, let value = Double(text[text.startIndex..<end]) else {
            return nil
        }
        let after = consumeSingleTrailingSpace(in: text, from: end)
        return Quantity(value: value, afterIndex: after)
    }

    private static func scanInteger(in text: String, from index: String.Index) -> String.Index {
        var cursor = index
        // DUT-351: `isWholeNumber` (not `isNumber`) so a glued unicode vulgar
        // fraction like "½" in "1½" stops the integer run instead of being swallowed
        // into it (which made `Double("1½")` nil and broke glued mixed numbers).
        while cursor < text.endIndex, text[cursor].isWholeNumber {
            cursor = text.index(after: cursor)
        }
        return cursor
    }

    private static func skipWhitespace(in text: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
        return cursor
    }

    /// Consume one trailing space after the parsed quantity so the rewritten
    /// quantity glues onto its unit with a single space (`"½ cup"`, not
    /// `"½  cup"`).
    private static func consumeSingleTrailingSpace(
        in text: String,
        from index: String.Index
    ) -> String.Index {
        guard index < text.endIndex, text[index] == " " else { return index }
        return text.index(after: index)
    }

    /// Unicode vulgar fractions the JSON-LD payload may carry directly.
    /// Mirrors `StepTimerParser.vulgarFractions` so the two parsers agree.
    private static let unicodeFractionValues: [Character: Double] = [
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

extension FractionRenderer {

    /// Quick helper for the warning copy in the view layer. Centralizing
    /// the threshold here means future tuning lives in one place.
    /// Spec trace: AC-31.6 — warning kicks in past 12 servings on a
    /// 5-quart home dutch oven.
    public static let dutchOvenServingWarningThreshold: Int = 12

    /// Public so view-model + view share one decision.
    public static func shouldShowDutchOvenWarning(forServings count: Int) -> Bool {
        count > dutchOvenServingWarningThreshold
    }
}

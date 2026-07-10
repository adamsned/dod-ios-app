import DODDomain
import Foundation

/// Scales recipe nutrition facts by the same servings ratio the ingredient
/// list already applies (``RecipeDetailViewModel/servingsScaleFactor``).
///
/// Nutrition values arrive from JSON-LD as strings with an inline unit
/// ("12 g", "240 kcal") — see `RecipeNutrition`. Scaling re-parses the
/// leading numeric quantity, multiplies it by `ratio`, and re-renders it
/// with the original trailing text (unit + whatever whitespace followed
/// the number) untouched. A value with no parseable leading number — or a
/// `nil` value — passes through unchanged, so a malformed / absent
/// nutrition string never crashes or fabricates a unit.
///
/// Pure, testable, no view/view-model dependency (mirrors `FractionRenderer`,
/// the equivalent scaler already used for ingredient quantities).
///
/// Spec trace: DUT-895 (iOS parity twin of DUT-892 / Android).
public enum NutritionScaler {

    /// Scales every numeric nutrition field on `nutrition` by `ratio`.
    /// `servingSize` (the size of ONE serving, e.g. "1 cup") is NOT a
    /// scaling target — it describes a single serving regardless of how
    /// many the user is now making — so it passes through unchanged.
    /// Returns `nil` when `nutrition` is `nil`.
    public static func scaledNutrition(_ nutrition: RecipeNutrition?, by ratio: Double) -> RecipeNutrition? {
        guard let nutrition else { return nil }
        return RecipeNutrition(
            calories: scale(nutrition.calories, by: ratio),
            servingSize: nutrition.servingSize,
            proteinGrams: scale(nutrition.proteinGrams, by: ratio),
            carbsGrams: scale(nutrition.carbsGrams, by: ratio),
            fatGrams: scale(nutrition.fatGrams, by: ratio)
        )
    }

    /// Re-renders one nutrition value string with its leading numeric
    /// quantity multiplied by `ratio`, keeping the trailing unit text
    /// untouched.
    ///
    /// - Parameters:
    ///   - value: One nutrition string (e.g. "12 g", "240 kcal"), or `nil`.
    ///   - ratio: Scaling multiplier (e.g. `userServings / sourceServings`,
    ///     the same ratio `FractionRenderer.scale` applies to ingredients).
    /// - Returns: The rewritten value, or the original value unchanged
    ///   when `ratio` is a no-op or nothing numeric could be parsed.
    ///   `nil` in, `nil` out.
    public static func scale(_ value: String?, by ratio: Double) -> String? {
        guard let value else { return nil }
        guard ratio.isFinite, ratio > 0, ratio != 1.0 else { return value }
        guard let parsed = parseLeadingNumber(in: value) else { return value }
        let scaledValue = parsed.value * ratio
        let rendered = render(scaledValue)
        let trailing = value[parsed.afterIndex...]
        // `parseLeadingNumber` consumed (at most) one space gluing the number
        // to its unit — re-add exactly what it swallowed so the rewritten
        // number keeps the same gap: "24 g" (not "24g") when the source had
        // one, "24g" (not "24 g") when the source didn't (mirrors
        // `FractionRenderer.scale`'s `consumedSpaceBeforeTrailing` gap).
        let gap = parsed.hadTrailingSpace ? " " : ""
        return rendered + gap + trailing
    }

    // MARK: - Internals

    /// One parse hit on the head of a nutrition string.
    private struct ParsedNumber {
        let value: Double
        let afterIndex: String.Index
        let hadTrailingSpace: Bool
    }

    /// Parse a leading non-negative integer or decimal quantity off the
    /// head of `text` ("12", "12.5"). Returns the index just past the
    /// number, with a single trailing space consumed if present (so a
    /// re-rendered number glues onto its unit with one space: "24 g", not
    /// "24  g"). Returns `nil` when `text` doesn't start with a digit.
    private static func parseLeadingNumber(in text: String) -> ParsedNumber? {
        guard let firstChar = text.first, firstChar.isWholeNumber else { return nil }
        var cursor = scanDigits(in: text, from: text.startIndex)
        if cursor < text.endIndex, text[cursor] == "." {
            let afterDot = text.index(after: cursor)
            let fracEnd = scanDigits(in: text, from: afterDot)
            if fracEnd > afterDot {
                cursor = fracEnd
            }
        }
        guard let value = Double(text[text.startIndex..<cursor]) else { return nil }
        var after = cursor
        var hadTrailingSpace = false
        if after < text.endIndex, text[after] == " " {
            after = text.index(after: after)
            hadTrailingSpace = true
        }
        return ParsedNumber(value: value, afterIndex: after, hadTrailingSpace: hadTrailingSpace)
    }

    private static func scanDigits(in text: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < text.endIndex, text[cursor].isWholeNumber {
            cursor = text.index(after: cursor)
        }
        return cursor
    }

    /// Rounds to at most one decimal place, dropping the decimal entirely
    /// when it rounds to a whole number ("24.0" renders "24"). A display
    /// formatter (deliberately locale-aware, not pinned — mirrors
    /// `FractionRenderer.fallbackFormatter`'s reasoning: this is text the
    /// user reads, not a value we parse back).
    private static func render(_ value: Double) -> String {
        displayFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static let displayFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

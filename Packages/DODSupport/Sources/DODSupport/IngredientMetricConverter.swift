import Foundation

/// Pure helper that rewrites an imperial-measured ingredient line into its
/// metric equivalent, leaving anything it can't confidently convert byte for
/// byte unchanged. A display-time transform only — callers map the (already
/// servings-scaled) ingredient text through it at render time and never mutate
/// the cached recipe (mirrors how ``FractionRenderer`` scales ingredient text
/// and ``TemperatureConverter`` rewrites step temperatures).
///
/// It reuses ``IngredientLineParser`` to recover the leading `(quantity, unit)`
/// so the two surfaces agree on what a "1 1/2 cups" prefix means, then converts
/// just the quantity + unit and re-emits `"<qty> <metric-unit> <name>"`.
///
/// ## What it converts (canonical unit → metric)
/// - Volume → millilitres: cup→240, tablespoon→15, teaspoon→5, pint→475,
///   quart→950. A result ≥ 1000 ml is expressed in litres (one decimal, a
///   trailing `.0` trimmed): `"1.9 L"`, `"2 L"`.
/// - Mass → grams: pound→450, ounce→28. A result ≥ 1000 g is expressed in
///   kilograms (one decimal, trailing `.0` trimmed): `"1.4 kg"`, `"2 kg"`.
///
/// ## What it deliberately leaves alone (returned unchanged)
/// - Already-metric units: gram, kilogram, millilitre, litre.
/// - Count / descriptive units: clove, can, package, sprig, stick, slice,
///   pinch (a metric mass for "2 cloves" would be nonsense).
/// - Any line with no parseable leading quantity **or** no recognized unit.
/// - Defensive: a converted magnitude that is zero or non-finite.
///
/// ## Rounding
/// Cooking-friendly: millilitre / gram results round to the nearest 5 when
/// below 100 and to the nearest 10 at or above 100 (how a cook reads a scale
/// or measuring jug), and are formatted as integers — so `1 cup` (240 ml) reads
/// as `"240 ml"`, not an inflated `"250 ml"`. Litre / kilogram results keep a
/// single decimal.
///
/// A very small measure that would round to a whole `0` (any true magnitude
/// under 2.5 ml/g, e.g. `1/4 teaspoon` → 1.25 ml) is instead shown to one
/// decimal place (`"1.3 ml"`, trailing `.0` trimmed) so a real positive amount
/// is never rendered as `"0 ml"` / `"0 g"`. A trace micro-amount below even one
/// decimal's resolution (magnitude < 0.05, e.g. `1/200 teaspoon` → 0.025 ml,
/// where one decimal would still collapse to `"0"`) reads as `"<0.1 ml"` /
/// `"<0.1 g"` — an honest "less than a tenth", never a false `"0 ml"` (DUT-540).
///
/// Spec trace: DUT-517 (ingredient metric half of the unit toggle, US-32
/// AC-32.4) — the deferred other half of DUT-47 / DUT-307.
public enum IngredientMetricConverter {

    /// Rewrite one ingredient line to metric, or return it unchanged when it
    /// can't be confidently converted (see the type doc for the full pass-through
    /// contract).
    public static func metric(_ text: String) -> String {
        let parsed = IngredientLineParser.parse(text)
        guard
            let quantity = parsed.quantity,
            let unit = parsed.unit,
            let conversion = conversions[unit]
        else {
            return text
        }
        let magnitude = quantity * conversion.factor
        guard magnitude.isFinite, magnitude > 0 else { return text }

        let unitText = format(magnitude, as: conversion.dimension)
        let name = parsed.name ?? ""
        return name.isEmpty ? unitText : "\(unitText) \(name)"
    }

    // MARK: - Shared preference contract

    /// Canonical `UserDefaults` key for the "Use Metric Units" ingredient
    /// display preference. Declared here, in the shared layer, so the two
    /// surfaces that touch it stay decoupled: `DODFeatureFeed`'s Settings
    /// toggle *writes* the bool (`SettingsViewModel.useMetricUnitsKey`) and
    /// `DODFeatureRecipeDetail` *reads* it via `@AppStorage` at render time,
    /// without either feature depending on the other. Mirrors how
    /// ``TemperatureConverter/preferenceKey`` is owned next to its converter.
    ///
    /// Wire format — must match `SettingsViewModel.useMetricUnitsKey` exactly;
    /// never rename without a migration shim (the value lands in `UserDefaults`
    /// on every device that has touched the toggle).
    public static let preferenceKey = "dod.settings.useMetricUnits"

    // MARK: - Formatting

    /// Render a base-unit magnitude (millilitres or grams) as its cooking-ready
    /// display string, rolling up to the larger unit at the 1000 threshold.
    private static func format(_ magnitude: Double, as dimension: Dimension) -> String {
        if magnitude >= 1000 {
            let large = magnitude / 1000
            return "\(trimDecimal(large)) \(dimension.largeSymbol)"
        }
        let rounded = roundBase(magnitude)
        // A real positive amount must never render as "0 ml" / "0 g": when the
        // cooking-friendly rounding collapses a tiny measure to a whole 0 (e.g.
        // 1/4 tsp → 1.25 ml), fall back to one decimal place so the true amount
        // is shown accurately (1.25 → "1.3 ml", trailing ".0" trimmed).
        if rounded == 0 {
            let oneDecimal = trimDecimal(magnitude)
            // Even one decimal collapses to "0" for a true micro-amount (any
            // magnitude < 0.05, e.g. 1/200 tsp → 0.025 ml). Rendering "0.0 ml"
            // would still read as nothing, so show an honest "less than a tenth"
            // trace marker instead of a false zero (DUT-540).
            if oneDecimal == "0" {
                return "<0.1 \(dimension.baseSymbol)"
            }
            return "\(oneDecimal) \(dimension.baseSymbol)"
        }
        return "\(formatInteger(rounded)) \(dimension.baseSymbol)"
    }

    /// Cooking-friendly base-unit rounding: nearest 5 below 100, nearest 10 at
    /// or above 100 (nearest 10 keeps whole-cup amounts honest — 240 ml stays
    /// 240, not an inflated 250).
    private static func roundBase(_ magnitude: Double) -> Double {
        let step: Double = magnitude < 100 ? 5 : 10
        return (magnitude / step).rounded() * step
    }

    /// Format a whole-number base magnitude without a trailing decimal.
    private static func formatInteger(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    /// Format a litre / kilogram magnitude to one decimal, trimming a trailing
    /// `.0` so `2.0` reads as `"2"`.
    private static func trimDecimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded.rounded()))
        }
        // DUT-737: render the one-decimal fraction through a locale-aware
        // formatter so a comma-decimal-locale cook reads "1,2 L", not the POSIX
        // "1.2 L". `String(format: "%.1f")` always pins the C-locale period —
        // the same bug DUT-320 fixed for `FractionRenderer`, and metric mode is
        // exactly the surface a non-US cook enables.
        return Self.decimalFormatter.string(from: NSNumber(value: rounded))
            ?? String(rounded)
    }

    /// DUT-737 — locale-aware one-decimal formatter for the L/kg rollup, mirroring
    /// `FractionRenderer.fallbackFormatter`. Grouping off (magnitudes are small
    /// post-rollup); the integer path is handled separately by `formatInteger`.
    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    // MARK: - Tables

    /// A convertible imperial unit's metric target: the multiplier onto the
    /// base metric unit and which base/large symbols to render.
    private struct Conversion {
        let factor: Double
        let dimension: Dimension
    }

    /// The two metric dimensions this converter targets, each with its base
    /// (< 1000) and rolled-up (≥ 1000) display symbols.
    private enum Dimension {
        case volume
        case mass

        var baseSymbol: String {
            switch self {
            case .volume: "ml"
            case .mass: "g"
            }
        }

        var largeSymbol: String {
            switch self {
            case .volume: "L"
            case .mass: "kg"
            }
        }
    }

    /// Maps each convertible canonical unit (as ``IngredientLineParser``
    /// normalizes it) to its metric conversion. Already-metric and
    /// count/descriptive units are intentionally absent — an absent key is the
    /// signal to pass the line through unchanged.
    private static let conversions: [String: Conversion] = [
        "cup": Conversion(factor: 240, dimension: .volume),
        "tablespoon": Conversion(factor: 15, dimension: .volume),
        "teaspoon": Conversion(factor: 5, dimension: .volume),
        "pint": Conversion(factor: 475, dimension: .volume),
        "quart": Conversion(factor: 950, dimension: .volume),
        "pound": Conversion(factor: 450, dimension: .mass),
        "ounce": Conversion(factor: 28, dimension: .mass),
    ]
}

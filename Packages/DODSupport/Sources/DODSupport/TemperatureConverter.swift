import Foundation

/// The temperature scale a recipe step's text should display in. Drives
/// ``TemperatureConverter/converting(_:to:)``.
///
/// Spec trace: DUT-47 (unit toggle — temperature half). The ingredient
/// metric/imperial half is deferred (it needs DUT-43's quantity parser).
public enum TemperatureUnit: Sendable, Hashable {
    case fahrenheit
    case celsius
}

/// Pure helper that rewrites EXPLICIT-unit temperatures inside free-text
/// recipe instructions to a target scale, leaving everything else byte for
/// byte unchanged. A display-time transform only — callers map the stored
/// `RecipeInstruction.text` through it at render time and never mutate the
/// cached recipe (mirrors how ``FractionRenderer`` scales ingredient text).
///
/// Why this lives in `DODSupport` (not in `DODFeatureRecipeDetail`): like
/// ``TitleSearchMatcher`` and ``StepTimerParser`` it is a pure,
/// Foundation-only value function with no UI dependency, and a future
/// surface (Cook Mode, the read-aloud reader, a share-sheet export) may
/// want the same contract without a feature-package dependency.
///
/// ## What it detects (case-insensitive)
/// An explicit-unit temperature is a number immediately (optionally across
/// one space) followed by a *scale signal*:
/// - a degree symbol + scale letter: `350°F`, `350 °F`, `175°C`
/// - a bare scale letter glued / spaced to the number: `350F`, `350 F`
/// - the word `degrees` + a scale letter or full word: `350 degrees F`,
///   `350 degrees Fahrenheit`
/// - a spelled-out scale word on its own: `425 Fahrenheit`, `180 Celsius`
///
/// Ranges convert both ends: `350-375°F`, `350 to 375°F` (the unit may sit
/// only on the right end and still apply to the left), and `350°F to 400°F`
/// (a unit on each end).
///
/// ## What it deliberately leaves alone
/// - Bare numbers with no scale signal — `bake at 350`, `tilt 90 degrees`
///   (a `°` or `degrees` with no F/C is NOT enough). This avoids false
///   positives on times / quantities / counts and is a documented
///   limitation (DUT-47 follow-up: opt-in bare-number detection).
/// - Times, quantities, counts — `30 minutes`, `2 cups`, `5 fresh leaves`.
/// - Text already in the target unit (returned unchanged for that span).
///
/// ## Rounding
/// Cooking-friendly: F→C rounds to the nearest 5 °C; C→F rounds to the
/// nearest 5 °F (how a cook reads an oven dial). The round-trip is NOT
/// guaranteed to recover the exact original — that asymmetry is intended.
///
/// ## Style preservation
/// The original spelling is preserved span-by-span: the degree symbol, the
/// space before it, the `degrees` word, and the scale token's form
/// (single letter vs spelled-out word) and letter case all carry over, so
/// `350°F` → `175°C`, `350 degrees Fahrenheit` → `175 degrees Celsius`,
/// `350F` → `175C`.
///
/// Spec trace: DUT-47 (temperature half).
public enum TemperatureConverter {

    /// Rewrites every explicit-unit temperature in `text` to `unit`,
    /// returning the text with only those substrings changed. Text with no
    /// detectable temperature (or already in the target unit) is returned
    /// unchanged.
    public static func converting(_ text: String, to unit: TemperatureUnit) -> String {
        let matches = scan(text)
        guard !matches.isEmpty else { return text }

        var output = ""
        output.reserveCapacity(text.count)
        var cursor = text.startIndex
        for match in matches {
            output += text[cursor..<match.range.lowerBound]
            output += render(match, to: unit)
            cursor = match.range.upperBound
        }
        output += text[cursor...]
        return output
    }

    // MARK: - Temperature extraction

    /// Extracts every explicit-unit temperature in `text` and returns their
    /// magnitudes **in Fahrenheit** — Celsius matches are converted to °F with
    /// the same cooking-friendly rounding as ``converting(_:to:)`` (nearest
    /// 5°F). Fahrenheit matches keep their integer magnitude.
    ///
    /// Reuses the same explicit-unit scanner as ``converting(_:to:)`` (a number
    /// followed by a `°F` / `°C` / `degrees …` / spelled-out scale signal), so
    /// it inherits the same "leave bare numbers alone" contract — `bake at 350`
    /// yields no value, avoiding false positives on times / quantities / counts.
    /// Ranges contribute *both* ends (e.g. `350-375°F` → `[350, 375]`).
    ///
    /// Order follows the source text; callers that want a single oven
    /// temperature typically take the `max`. Returns an empty array when the
    /// text carries no detectable explicit-unit temperature.
    ///
    /// Used by ``RecipeHeatProfile`` to derive a recipe's oven temperature from
    /// its free-text steps without a UI or feature-package dependency.
    public static func fahrenheitValues(in text: String) -> [Int] {
        scan(text).flatMap { match -> [Int] in
            match.values.map { value in
                switch match.scale {
                case .fahrenheit:
                    // Already Fahrenheit — round to a whole degree; sources are
                    // integers in practice, this just drops any decimal look.
                    return Int(value.magnitude.rounded())
                case .celsius:
                    // Convert C→F with the shared nearest-5°F rounding.
                    return convert(value.magnitude, to: .fahrenheit)
                }
            }
        }
    }

    // MARK: - Shared preference contract

    /// Canonical `UserDefaults` key for the recipe-step temperature display
    /// preference. Declared here, in the shared layer, so the two surfaces
    /// that touch it stay decoupled: `DODFeatureFeed`'s Settings picker
    /// *writes* the value (its `TemperaturePreference.rawValue`) and
    /// `DODFeatureRecipeDetail` *reads* it via `@AppStorage` at render time,
    /// without either feature depending on the other. Mirrors how
    /// `DODPersistence` owns `RecipeStore.cloudKitSyncOptInKey` next to its
    /// reader.
    ///
    /// Wire format — never rename without a migration shim; the value lands
    /// in `UserDefaults` on every device that has touched the picker.
    public static let preferenceKey = "dod.settings.temperatureUnit"

    /// Resolve a persisted preference raw value to the unit the converter
    /// should target, or `nil` when no conversion should happen. `nil` is
    /// returned for an absent value, the `"recipeDefault"` ("show as
    /// written") selection, and any unrecognized string (defensive — a
    /// malformed value must degrade to "leave the text alone", never crash).
    public static func resolvedUnit(fromRawValue rawValue: String?) -> TemperatureUnit? {
        switch rawValue {
        case "fahrenheit": .fahrenheit
        case "celsius": .celsius
        default: nil
        }
    }

    // MARK: - Match model

    /// The detected scale of one temperature token.
    enum Scale {
        case fahrenheit
        case celsius
    }

    /// How the scale was spelled, so the output can preserve it. The
    /// associated `String` is the *original substring* (e.g. `"F"`,
    /// `"fahrenheit"`, `"Celsius"`) — its case + length drive the
    /// re-rendered token via ``Word/converted(to:)``.
    enum ScaleWord {
        /// A single scale letter: `F` / `C` (any case).
        case letter(String)
        /// A spelled-out scale word: `Fahrenheit` / `Celsius` (any case).
        case word(String)
    }

    /// One numeric value inside a (possibly range) temperature, with the
    /// exact source span so it can be replaced in place. Pulled into a
    /// struct (not a tuple) to satisfy the large-tuple lint rule.
    struct Value {
        /// The parsed numeric magnitude (e.g. `350`, `212.0`).
        let magnitude: Double
        /// The original digits substring, used to detect a decimal point so
        /// the output keeps an integer look unless the source was decimal.
        let literal: String
        /// Source range of just the number, for in-place replacement.
        let range: Range<String.Index>
    }

    /// One fully-resolved temperature occurrence (single value or a range).
    /// `range` spans from the first digit through the trailing unit so the
    /// whole occurrence is rewritten as a unit.
    struct Match {
        let values: [Value]
        let scale: Scale
        let scaleWord: ScaleWord
        /// Verbatim text between the two range values (e.g. `"-"`, `" to "`),
        /// or `nil` for a single (non-range) temperature. Reproduced exactly
        /// in the output so en-dashes / the `to` word / spacing carry over.
        let separator: String?
        /// The unit suffix string as it appeared after the last value
        /// (e.g. `"°F"`, `" degrees Fahrenheit"`, `"C"`) — reused verbatim
        /// except for the scale letter/word, which is converted.
        let unitSuffix: String
        let range: Range<String.Index>
    }
}

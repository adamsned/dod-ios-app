import Foundation
import Testing

@testable import DODSupport

/// Regression tests locking DUT-737: the L/kg one-decimal path uses a
/// locale-aware `NumberFormatter` so a comma-decimal cook reads "1,2 L" and
/// not the POSIX "1.2". `NumberFormatter` with an explicit `Locale(identifier:)`
/// is deterministic regardless of the host machine's locale, so these pass
/// stably in CI.
///
/// Input derivations (for the reader's benefit):
/// - Volume path: 5 quarts × 950 ml = 4750 ml → 4.75 L → one-decimal (not
///   a whole number) → formatter fires → "4.8 L water" / "4,8 L water".
/// - Mass path:   3 pounds × 450 g  = 1350 g  → 1.35 kg → one-decimal →
///   formatter fires → "1.4 kg flour" / "1,4 kg flour".
@Suite("IngredientMetricConverter locale-aware decimal separator (DUT-737)")
struct IngredientMetricConverterLocaleTests {

    // MARK: - Volume (L) path

    @Test func litersUsePeriodForPOSIXLocale() {
        // en_US_POSIX is the canonical "always-period" locale.
        let result = IngredientMetricConverter.metric(
            "5 quarts water",
            locale: Locale(identifier: "en_US_POSIX")
        )
        #expect(result == "4.8 L water")
    }

    @Test func litersUseCommaForFrenchLocale() {
        // fr_FR decimal separator is a comma — the bug DUT-737 fixed.
        let result = IngredientMetricConverter.metric(
            "5 quarts water",
            locale: Locale(identifier: "fr_FR")
        )
        #expect(result == "4,8 L water")
    }

    // MARK: - Mass (kg) path

    @Test func kilogramsUsePeriodForPOSIXLocale() {
        let result = IngredientMetricConverter.metric(
            "3 pounds flour",
            locale: Locale(identifier: "en_US_POSIX")
        )
        #expect(result == "1.4 kg flour")
    }

    @Test func kilogramsUseCommaForFrenchLocale() {
        let result = IngredientMetricConverter.metric(
            "3 pounds flour",
            locale: Locale(identifier: "fr_FR")
        )
        #expect(result == "1,4 kg flour")
    }

    // MARK: - Integer ml/g values: locale has no effect (no decimal point)

    @Test func integerMillilitersUnaffectedByLocale() {
        // 1 cup × 240 ml = 240 ml — integer result, formatInteger path, formatter
        // never called. Both locales must produce the same string.
        let posix = IngredientMetricConverter.metric(
            "1 cup sugar",
            locale: Locale(identifier: "en_US_POSIX")
        )
        let french = IngredientMetricConverter.metric(
            "1 cup sugar",
            locale: Locale(identifier: "fr_FR")
        )
        #expect(posix == "240 ml sugar")
        #expect(french == "240 ml sugar")
    }
}

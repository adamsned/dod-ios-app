import DODDomain
import DODSupport
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the DUT-47 (temperature half) Recipe Detail wiring: the
/// `InstructionStepView` display-text seam plus the exact gate the
/// instructions section composes — resolve the persisted preference raw
/// value to a unit, then (only when non-`nil`) map the step text through
/// ``DODSupport/TemperatureConverter``.
///
/// The conversion math + detection rules are pinned in `DODSupport`'s
/// `TemperatureConverterTests`; these tests pin the *integration contract*
/// Recipe Detail depends on — that "Recipe default" / absent is a no-op and
/// a chosen unit rewrites the displayed (and VoiceOver-read) text — so the
/// view's `@AppStorage`-gated render path can't silently regress.
///
/// Spec trace: DUT-47 (temperature half).
@Suite("InstructionStep temperature display (DUT-47)") struct InstructionStepTemperatureTests {

    @Test func displayTextDefaultsToStepTextWhenUnset() {
        // No explicit displayText → the view shows the stored step text
        // verbatim (the "Recipe default" path passes nothing extra).
        let step = RecipeInstruction(step: 1, text: "Preheat to 350°F.")
        let view = InstructionStepView(step: step)
        #expect(view.displayText == "Preheat to 350°F.")
    }

    @Test func displayTextOverrideIsHonored() {
        let step = RecipeInstruction(step: 1, text: "Preheat to 350°F.")
        let view = InstructionStepView(step: step, displayText: "Preheat to 175°C.")
        #expect(view.displayText == "Preheat to 175°C.")
    }

    // MARK: - The exact gate the instructions section composes

    /// Mirrors `RecipeDetailView.convertedStepText(_:to:)`: resolve the raw
    /// preference, and convert only when a unit is selected.
    private func displayText(for stepText: String, rawPreference: String?) -> String {
        guard let unit = TemperatureConverter.resolvedUnit(fromRawValue: rawPreference) else {
            return stepText
        }
        return TemperatureConverter.converting(stepText, to: unit)
    }

    @Test func recipeDefaultLeavesStepUnchanged() {
        let step = "Bake at 350°F for 20 minutes."
        // "recipeDefault", an absent value, and an unknown value all no-op.
        #expect(displayText(for: step, rawPreference: "recipeDefault") == step)
        #expect(displayText(for: step, rawPreference: nil) == step)
        #expect(displayText(for: step, rawPreference: "kelvin") == step)
    }

    @Test func celsiusPreferenceConvertsFahrenheitStep() {
        let result = displayText(for: "Bake at 350°F for 20 minutes.", rawPreference: "celsius")
        // 350°F → 175°C; the "20 minutes" time is left untouched.
        #expect(result == "Bake at 175°C for 20 minutes.")
    }

    @Test func fahrenheitPreferenceConvertsCelsiusStep() {
        let result = displayText(for: "Bake at 180°C.", rawPreference: "fahrenheit")
        // 180°C → 356°F → nearest 5 → 355°F.
        #expect(result == "Bake at 355°F.")
    }
}

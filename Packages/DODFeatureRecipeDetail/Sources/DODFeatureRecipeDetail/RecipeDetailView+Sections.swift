import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

extension RecipeDetailView {

    // MARK: - Ingredients + Instructions

    // Extracted from `RecipeDetailView` (T-804) so the main struct's body stays
    // under the SwiftLint `type_body_length` cap after the iPad adaptive-layout
    // restructure. These are the two sections the landscape two-up lays side by
    // side; `readyBody` (in the main file) decides stacked vs. side-by-side.

    var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            // DUT-529: only emit the header when there's an actual list to show —
            // a `.ready` recipe with no ingredients otherwise renders a bare
            // "Ingredients" title with no rows beneath it.
            if let ingredients = viewModel.recipe?.ingredients, !ingredients.isEmpty {
                Text("Ingredients")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
                // US-31 / AC-31.4 + AC-31.5: scale at render time.
                // Source recipe `ingredient.text` stays untouched (AC-31.8).
                let factor = viewModel.servingsScaleFactor
                ForEach(ingredients) { ingredient in
                    IngredientCheckRow(
                        ingredient: ingredient,
                        displayText: displayIngredientText(ingredient.text, scaledBy: factor),
                        isChecked: viewModel.checkedIngredientIDs.contains(ingredient.id),
                        onToggle: { viewModel.toggleIngredient(ingredient.id) }
                    )
                }
            }
        }
        .padding(.horizontal, DODSpacing.md)
    }

    /// The display string for one ingredient row: scale the source text for the
    /// chosen servings (US-31 / AC-31.4), then — when "Use Metric Units" is on
    /// (DUT-517) — convert the ALREADY-SCALED line to metric. Order matters: the
    /// converter reads the post-scale quantity, so `"1 cup" ×2 → "2 cups" →
    /// "475 ml"`. Non-convertible lines fall through unchanged.
    func displayIngredientText(_ text: String, scaledBy factor: Double) -> String {
        let scaled = FractionRenderer.scale(text, by: factor)
        return useMetricUnits ? IngredientMetricConverter.metric(scaled) : scaled
    }

    var instructionsSection: some View {
        // DUT-47 (temperature half): resolve the unit once per render. `nil`
        // ("Recipe default" / absent / malformed) leaves every step exactly
        // as written; otherwise each step's text is mapped through the
        // converter at display time (stored data untouched, AC-31.8-style).
        let temperatureUnit = TemperatureConverter.resolvedUnit(fromRawValue: temperatureUnitRaw)
        return VStack(alignment: .leading, spacing: DODSpacing.md) {
            // DUT-529: gate the header on a non-empty list so a `.ready` recipe
            // with no instructions doesn't show a lone "Instructions" title.
            if let instructions = viewModel.recipe?.instructions, !instructions.isEmpty {
                Text("Instructions")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
                ForEach(instructions) { step in
                    InstructionStepView(
                        step: step,
                        displayText: convertedStepText(step.text, to: temperatureUnit)
                    )
                }
            }
        }
        .padding(.horizontal, DODSpacing.md)
    }

    /// Apply the DUT-47 temperature conversion to one step's text, or return it
    /// unchanged when no unit is selected. Extracted so the `ForEach` body
    /// stays a single expression and the gating logic reads in one place.
    func convertedStepText(_ text: String, to unit: TemperatureUnit?) -> String {
        guard let unit else { return text }
        return TemperatureConverter.converting(text, to: unit)
    }
}

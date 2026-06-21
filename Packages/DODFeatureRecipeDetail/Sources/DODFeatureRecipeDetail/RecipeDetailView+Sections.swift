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
            Text("Ingredients")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            if let ingredients = viewModel.recipe?.ingredients {
                // US-31 / AC-31.4 + AC-31.5: scale at render time.
                // Source recipe `ingredient.text` stays untouched (AC-31.8).
                let factor = viewModel.servingsScaleFactor
                ForEach(ingredients) { ingredient in
                    IngredientCheckRow(
                        ingredient: ingredient,
                        displayText: FractionRenderer.scale(ingredient.text, by: factor),
                        isChecked: viewModel.checkedIngredientIDs.contains(ingredient.id),
                        onToggle: { viewModel.toggleIngredient(ingredient.id) }
                    )
                }
            }
        }
        .padding(.horizontal, DODSpacing.md)
    }

    var instructionsSection: some View {
        // DUT-47 (temperature half): resolve the unit once per render. `nil`
        // ("Recipe default" / absent / malformed) leaves every step exactly
        // as written; otherwise each step's text is mapped through the
        // converter at display time (stored data untouched, AC-31.8-style).
        let temperatureUnit = TemperatureConverter.resolvedUnit(fromRawValue: temperatureUnitRaw)
        return VStack(alignment: .leading, spacing: DODSpacing.md) {
            Text("Instructions")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            if let instructions = viewModel.recipe?.instructions {
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

import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

/// DUT-168 — compact "For this step" ingredient sub-list under a Cook Mode step.
/// Renders nothing when `ingredients` is empty.
struct CookModeStepIngredientsList: View {
    let ingredients: [RecipeIngredient]
    let scaleFactor: Double
    let useMetricUnits: Bool

    /// Scaled (and optionally metric) display text, same pipeline as the drawer.
    func displayText(for ingredient: RecipeIngredient) -> String {
        let scaled = FractionRenderer.scale(ingredient.text, by: scaleFactor)
        return useMetricUnits ? IngredientMetricConverter.metric(scaled) : scaled
    }

    var body: some View {
        if !ingredients.isEmpty {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Text("For this step")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .accessibilityAddTraits(.isHeader)
                ForEach(ingredients) { ingredient in
                    Text(displayText(for: ingredient))
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cook-mode-step-ingredients")
        }
    }
}

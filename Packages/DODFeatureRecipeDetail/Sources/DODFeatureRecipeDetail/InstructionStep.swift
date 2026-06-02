import DODDesignSystem
import DODDomain
import SwiftUI

/// Numbered step row.
public struct InstructionStepView: View {

    public let step: RecipeInstruction

    public init(step: RecipeInstruction) {
        self.step = step
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DODSpacing.md) {
            Text("\(step.step)")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.cream)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DODColor.burntOrange))
                .accessibilityHidden(true)
            Text(step.text)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .lineSpacing(DODSpacing.xxs)
                // DUT-17: wrap long instruction text to multiple lines rather
                // than overflowing the row horizontally. See IngredientCheckRow
                // for the rationale on pairing `.fixedSize` with `.frame`.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.step). \(step.text)")
    }
}

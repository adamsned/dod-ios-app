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
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.step). \(step.text)")
    }
}

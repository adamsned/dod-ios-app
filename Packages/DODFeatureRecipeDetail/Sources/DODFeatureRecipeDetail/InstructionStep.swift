import DODDesignSystem
import DODDomain
import SwiftUI

/// Numbered step row.
public struct InstructionStepView: View {

    public let step: RecipeInstruction
    /// The text actually shown (and read by VoiceOver). Defaults to
    /// `step.text`; Recipe Detail passes a temperature-converted variant
    /// when the DUT-47 unit preference is set (a render-time transform — the
    /// stored `step.text` is never mutated, mirroring how `IngredientCheckRow`
    /// takes a pre-scaled `displayText` separate from its model).
    public let displayText: String

    public init(step: RecipeInstruction, displayText: String? = nil) {
        self.step = step
        self.displayText = displayText ?? step.text
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DODSpacing.md) {
            Text("\(step.step)")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.cream)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DODColor.burntOrange))
                .accessibilityHidden(true)
            Text(displayText)
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
        .accessibilityLabel("Step \(step.step). \(displayText)")
    }
}

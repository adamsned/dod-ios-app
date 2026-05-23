import DODDesignSystem
import DODDomain
import SwiftUI

/// Tap-to-strike ingredient row. State held in the VM, not persisted (AC-4.2).
public struct IngredientCheckRow: View {

    public let ingredient: RecipeIngredient
    public let isChecked: Bool
    public let onToggle: () -> Void

    public init(ingredient: RecipeIngredient, isChecked: Bool, onToggle: @escaping () -> Void) {
        self.ingredient = ingredient
        self.isChecked = isChecked
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DODSpacing.sm) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? DODColor.accent : DODColor.labelSecondary)
                    .font(.title3)
                Text(ingredient.text)
                    .dodFont(DODType.body)
                    .foregroundStyle(isChecked ? DODColor.labelSecondary : DODColor.label)
                    .strikethrough(isChecked, color: DODColor.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, DODSpacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ingredient.text)
        .accessibilityValue(isChecked ? "checked" : "unchecked")
        .accessibilityAddTraits(isChecked ? [.isSelected] : [])
    }
}

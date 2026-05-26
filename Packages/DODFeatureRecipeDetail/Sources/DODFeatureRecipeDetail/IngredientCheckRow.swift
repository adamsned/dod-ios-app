import DODDesignSystem
import DODDomain
import SwiftUI

/// Tap-to-strike ingredient row. State held in the VM, not persisted (AC-4.2).
///
/// `displayText` is rendered in place of `ingredient.text` so the host view
/// can scale quantities per US-31 without mutating the source `Recipe`.
/// Defaults to `ingredient.text` so existing call sites keep their behavior.
public struct IngredientCheckRow: View {

    public let ingredient: RecipeIngredient
    public let displayText: String
    public let isChecked: Bool
    public let onToggle: () -> Void

    public init(
        ingredient: RecipeIngredient,
        displayText: String? = nil,
        isChecked: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.ingredient = ingredient
        self.displayText = displayText ?? ingredient.text
        self.isChecked = isChecked
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DODSpacing.sm) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? DODColor.accent : DODColor.labelSecondary)
                    .font(.title3)
                Text(displayText)
                    .dodFont(DODType.body)
                    .foregroundStyle(isChecked ? DODColor.labelSecondary : DODColor.label)
                    .strikethrough(isChecked, color: DODColor.labelSecondary)
                    .animation(.easeInOut(duration: 0.15), value: isChecked)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, DODSpacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(displayText)
        .accessibilityValue(isChecked ? "checked" : "unchecked")
        .accessibilityAddTraits(isChecked ? [.isSelected] : [])
    }
}

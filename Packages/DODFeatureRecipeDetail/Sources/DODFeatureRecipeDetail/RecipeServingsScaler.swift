import DODDesignSystem
import SwiftUI

/// Per-render serving-count scaler. Tap "−"/"+" to scale ingredient
/// quantities up or down without mutating the source ``Recipe``.
///
/// Spec trace: US-31 (recipe scaling). AC-31.1 (stepper presence near the
/// meta row), AC-31.2 (range), AC-31.6 (warning copy at >12 servings).
struct RecipeServingsScaler: View {

    @Binding var value: Int
    let range: ClosedRange<Int>
    /// Source `recipeYield` (JSON-LD per AC-4.11). Displayed in the
    /// secondary line so the user can see how far they've scaled.
    let sourceServings: Int
    /// True when ``value`` is past the home-dutch-oven physical-capacity
    /// threshold (CL-52). Drives the inline caption render.
    let showsWarning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            stepperRow
            if showsWarning {
                warningCaption
            }
        }
        .padding(.horizontal, DODSpacing.md)
    }

    private var stepperRow: some View {
        HStack(spacing: DODSpacing.sm) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(DODColor.labelSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Serves \(value)")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                if value != sourceServings {
                    Text("Recipe makes \(sourceServings).")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .accessibilityHidden(true)
                }
            }
            Spacer(minLength: DODSpacing.md)
            Stepper(
                "Serves \(value)",
                value: $value,
                in: range,
                step: 1
            )
            .labelsHidden()
            .accessibilityLabel("Servings")
            .accessibilityValue("\(value)")
        }
        .padding(.vertical, DODSpacing.xs)
        .padding(.horizontal, DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
    }

    /// Non-blocking caption. AC-31.6.
    private var warningCaption: some View {
        HStack(alignment: .top, spacing: DODSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DODColor.burntOrange)
                .accessibilityHidden(true)
            Text(
                "Most home dutch ovens (5-quart) cap out around 12 servings. "
                    + "Consider doubling the recipe in two batches instead."
            )
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DODSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Capacity warning. Most home dutch ovens cap out around 12 servings."
        )
    }
}

import DODDesignSystem
import SwiftUI

/// Compact pill row of meta facts (total time, servings) shown under the hero.
/// Each pill is a rounded SurfaceElevated chip with an SF Symbol + label.
struct RecipeDetailMetaPills: View {

    struct Item: Hashable {
        let icon: String
        let label: String
    }

    let items: [Item]

    var body: some View {
        if !items.isEmpty {
            HStack(spacing: DODSpacing.xs) {
                ForEach(items, id: \.self) { item in
                    pill(item: item)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DODSpacing.md)
        }
    }

    private func pill(item: Item) -> some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: item.icon)
                .foregroundStyle(DODColor.labelSecondary)
                // DUT-527 — hide the decorative SF Symbol so VoiceOver doesn't
                // read the raw glyph name; the explicit label below carries the
                // meaning (e.g. "45 minutes", "Serves 6").
                .accessibilityHidden(true)
            Text(item.label)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.label)
        }
        .padding(.horizontal, DODSpacing.sm)
        .padding(.vertical, DODSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.inner, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.label)
    }
}

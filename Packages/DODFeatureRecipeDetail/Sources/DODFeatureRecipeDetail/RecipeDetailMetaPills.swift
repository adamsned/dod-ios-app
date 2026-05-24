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
            Text(item.label)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.label)
        }
        .padding(.horizontal, DODSpacing.sm)
        .padding(.vertical, DODSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
    }
}

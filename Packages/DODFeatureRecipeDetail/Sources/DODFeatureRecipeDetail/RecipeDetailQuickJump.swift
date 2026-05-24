import DODDesignSystem
import SwiftUI

/// Horizontal row of pill buttons that scrolls the parent `ScrollView` to
/// the matching section anchor.
struct RecipeDetailQuickJump: View {

    struct Item: Hashable {
        let title: String
        let onTap: () -> Void

        static func == (lhs: Item, rhs: Item) -> Bool { lhs.title == rhs.title }
        func hash(into hasher: inout Hasher) { hasher.combine(title) }
    }

    let items: [Item]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DODSpacing.xs) {
                ForEach(items, id: \.self) { item in
                    pill(item: item)
                }
            }
            .padding(.horizontal, DODSpacing.md)
        }
    }

    private func pill(item: Item) -> some View {
        Button(action: item.onTap) {
            Text(item.title)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.label)
                .padding(.horizontal, DODSpacing.sm)
                .padding(.vertical, DODSpacing.xs)
                .background(Capsule(style: .continuous).fill(DODColor.surfaceElevated))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Jumps to \(item.title) section")
    }
}

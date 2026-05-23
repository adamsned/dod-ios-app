import DODDesignSystem
import DODDomain
import SwiftUI

/// Horizontal scroll of related recipes (AC-4.6).
/// Hidden when `items` is empty — caller filters by offline state per AC-5.6.
public struct RelatedRecipesStrip: View {

    public let items: [RecipeListItem]
    public let onSelect: (RecipeListItem) -> Void

    public init(items: [RecipeListItem], onSelect: @escaping (RecipeListItem) -> Void) {
        self.items = items
        self.onSelect = onSelect
    }

    public var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                Text("Related recipes")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
                    .padding(.horizontal, DODSpacing.md)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DODSpacing.sm) {
                        ForEach(items) { item in
                            relatedCard(item)
                                .onTapGesture { onSelect(item) }
                        }
                    }
                    .padding(.horizontal, DODSpacing.md)
                }
            }
            .padding(.vertical, DODSpacing.md)
        }
    }

    private func relatedCard(_ item: RecipeListItem) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            AsyncImage(url: item.heroImage) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    LoadingSkeleton(cornerRadius: 0)
                }
            }
            .frame(width: 160, height: 100)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DODSpacing.xs, style: .continuous))

            Text(item.title)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)
        }
    }
}

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
                Text("Related Recipes")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
                    .padding(.horizontal, DODSpacing.md)
                ScrollView(.horizontal, showsIndicators: false) {
                    // DUT — pin cards to a common top so 1-line vs 2-line
                    // (`lineLimit(2)`) titles never stair-step the hero thumbnails.
                    HStack(alignment: .top, spacing: DODSpacing.sm) {
                        ForEach(items) { item in
                            relatedCard(item)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(item) }
                                // T-610 — stable handle for the L5 related-recipes
                                // journey (tap a sibling → its detail).
                                // DUT-527 — the card is tapped via `.onTapGesture`
                                // on a VStack, which VoiceOver reads as static
                                // text with no action. Give it a button trait +
                                // an explicit combined label so VoiceOver
                                // announces "<title>, recipe, button".
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(item.title), recipe")
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("dod.related.card")
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
            // T-839 — reliable cached loader (ReliableImage), not AsyncImage,
            // so related-recipe thumbnails don't stick on the skeleton.
            ReliableImage(url: item.heroImage) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    // DUT-524 — neutral static placeholder instead of the
                    // infinite skeleton shimmer when a thumbnail can't load.
                    DODColor.surfaceElevated
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 28))
                                .foregroundStyle(DODColor.labelSecondary)
                        )
                case .empty:
                    LoadingSkeleton(cornerRadius: 0)
                }
            }
            .frame(width: 160, height: 100)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.inner, style: .continuous))

            Text(item.title)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)
        }
    }
}

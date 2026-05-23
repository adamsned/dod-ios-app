import DODDesignSystem
import DODDomain
import SwiftUI

/// Adapter from `RecipeListItem` to the DesignSystem `RecipeCard`.
/// Lives in the feature module so DesignSystem stays Domain-free (plan §1).
public struct FeedRow: View {

    public let item: RecipeListItem

    public init(item: RecipeListItem) {
        self.item = item
    }

    public var body: some View {
        RecipeCard(
            title: item.title,
            excerpt: item.excerpt,
            heroImageURL: item.heroImage,
            totalTimeDisplay: item.totalTimeDisplay
        )
    }
}

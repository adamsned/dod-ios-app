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
        // CL-254 (feed declutter) — no cook-time chip on the Recipes feed; it
        // reads as noise there. `totalTimeDisplay` is intentionally omitted
        // (defaults to nil → no chip). Time still shows on Search + the recipe
        // detail page for anyone who wants it.
        RecipeCard(
            title: item.title,
            excerpt: item.excerpt,
            heroImageURL: item.heroImage
        )
    }
}

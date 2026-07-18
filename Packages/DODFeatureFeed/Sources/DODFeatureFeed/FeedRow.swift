import DODDesignSystem
import DODDomain
import SwiftUI

/// Adapter from `RecipeListItem` to the DesignSystem `RecipeCard`.
/// Lives in the feature module so DesignSystem stays Domain-free (plan §1).
public struct FeedRow: View {

    public let item: RecipeListItem
    /// US-43 Phase b (T-711) — the compositional register forwarded to
    /// `RecipeCard`. Defaults `.classic` so any existing caller / preview is
    /// byte-identical; `FeedView` passes the resolved (default `.magazine`) value.
    public let variant: DODFeed.LayoutVariant

    public init(
        item: RecipeListItem,
        variant: DODFeed.LayoutVariant = .classic
    ) {
        self.item = item
        self.variant = variant
    }

    public var body: some View {
        // CL-254 (feed declutter) — no cook-time chip on the Recipes feed; it
        // reads as noise there. `totalTimeDisplay` is intentionally omitted
        // (defaults to nil → no chip). Time still shows on Search + the recipe
        // detail page for anyone who wants it. US-43 Phase b keeps the chip +
        // excerpt AS CAPABILITIES on `RecipeCard` (Spencer's Move-6 call); the
        // Feed's own chip-less choice is unchanged.
        RecipeCard(
            title: item.title,
            excerpt: item.excerpt,
            heroImageURL: item.heroImage,
            variant: variant
        )
    }
}

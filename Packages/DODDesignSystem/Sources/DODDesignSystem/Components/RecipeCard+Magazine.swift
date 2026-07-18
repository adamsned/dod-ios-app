import SwiftUI

// MARK: - Hero + magazine typography (US-43 Phase b, T-711)

/// The hero builder + variant-driven title font for ``RecipeCard``. Split to its
/// own file (extension on `RecipeCard`) so the main struct stays under the
/// SwiftLint `type_body_length` cap, mirroring the `RecipeCard+ListRow` split.
///
/// **Design choices (post first-cut review).** The 16:9 landscape hero explored
/// in the first cut was dropped: Spencer prefers the single-column row card
/// (`RecipeCard.ListRow`) for the magazine feed, so the gallery card keeps the
/// classic 140pt top-image crop and the magazine register expresses itself
/// through the bolder title + the borderless-on-light surface collapse (AC-43.2)
/// only. Both variants share one hero shape, so every gallery card is a uniform
/// size again (no per-card shrinking). The cook-time chip + excerpt remain card
/// capabilities (Spencer's Move-6 call, CL-114).
extension RecipeCard {

    /// The title typographic token per variant. `.magazine` steps up from
    /// `.headline` (semibold) to `DODType.displayMedium` (title2 `.bold`, the
    /// Phase-a section-header weight) for the editorial register.
    var titleFont: Font {
        switch variant {
        case .classic: DODType.heading
        case .magazine: DODType.displayMedium
        }
    }

    /// The 140pt fixed-height hero crop, shared by every variant so the gallery
    /// grid stays uniform. `DUT-195` — `ReliableImage` (not `AsyncImage`, which
    /// dropped thumbnails on scroll). The card's outer `clipShape` rounds the top.
    var heroImage: some View {
        ReliableImage(url: heroImageURL) { phase in
            switch phase {
            case .empty:
                LoadingSkeleton(cornerRadius: 0)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(DODColor.labelSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DODColor.surface)
            }
        }
        .frame(height: 140)
        .clipped()
    }
}

#Preview("Magazine gallery card") {
    RecipeCard(
        title: "Garlic Butter Skillet Corn",
        excerpt: "An easy 15-minute side dish that pairs with everything.",
        heroImageURL: URL(string: "https://www.dutchovendaddy.com/wp-content/uploads/sample.jpg"),
        variant: .magazine
    )
    .frame(width: 180)
    .padding(DODSpacing.md)
    .background(DODColor.surface)
}

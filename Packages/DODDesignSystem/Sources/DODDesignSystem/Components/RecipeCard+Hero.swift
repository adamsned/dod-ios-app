import SwiftUI

// MARK: - Hero image + editorial typography (US-43 Phase b, T-711)

/// The hero builder + title font for ``RecipeCard``. Split to its own file
/// (extension on `RecipeCard`) so the main struct stays under the SwiftLint
/// `type_body_length` cap, mirroring the `RecipeCard+ListRow` split.
///
/// **History.** This started as a `.classic` / `.magazine` register switch. The
/// 16:9 landscape hero and the numbered "Popular" badge were both dropped during
/// the design review, which left "magazine" meaning only a bolder title plus the
/// borderless-on-light surface collapse — not enough to justify a second code
/// path, and the Feed shipped it while Search/Saved/Categories silently kept the
/// old look. The switch was retired and the reviewed treatment is now simply the
/// card, applied everywhere. A real editorial layout (featured carousel or
/// varied-rhythm feed) is future work, not a styling flag.
extension RecipeCard {

    /// The card title token: title2 `.bold`, matching the Phase-a section-header
    /// weight for the editorial register.
    var titleFont: Font { DODType.displayMedium }

    /// The 140pt fixed-height hero crop, keeping every gallery card a uniform
    /// size. `DUT-195` — `ReliableImage` (not `AsyncImage`, which dropped
    /// thumbnails on scroll). The card's outer `clipShape` rounds the top.
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

#Preview("Gallery card") {
    RecipeCard(
        title: "Garlic Butter Skillet Corn",
        excerpt: "An easy 15-minute side dish that pairs with everything.",
        heroImageURL: URL(string: "https://www.dutchovendaddy.com/wp-content/uploads/sample.jpg")
    )
    .frame(width: 180)
    .padding(DODSpacing.md)
    .background(DODColor.surface)
}

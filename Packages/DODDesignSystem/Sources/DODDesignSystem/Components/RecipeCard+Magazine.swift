import SwiftUI

// MARK: - Magazine variant (US-43 Phase b, T-711)

/// The variant-driven hero + typography for ``RecipeCard``. Split to its own
/// file (extension on `RecipeCard`) so the main struct stays under the SwiftLint
/// `type_body_length` cap, mirroring the `RecipeCard+ListRow` split.
///
/// **Design choices (first cut).**
/// - `.classic` keeps the pre-refresh 140pt fixed-height hero and `.headline`
///   title byte-identical — reverting the ``DODFeed/LayoutVariant`` flag
///   restores the classic card exactly (its L4 baselines stay valid).
/// - `.magazine` moves the hero to the site's **16:9 landscape** crop (the gap
///   AC-43 named — the app shipped a portrait-ish 140pt box) and bolds the title
///   to the Phase-a display weight (`DODType.displayMedium`). The card keeps its
///   `DODColor.surfaceElevated` background, which collapses to `Surface` on light
///   mode (AC-43.2) so the card reads borderless-on-light. The cook-time chip and
///   the excerpt are intentionally KEPT (Spencer's Move-6 call, CL-114).
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

    /// The hero photo box. `.classic` is the original 140pt fixed-height,
    /// square-cornered crop (relies on the card's outer `clipShape` to round the
    /// top). `.magazine` is a full-width 16:9 landscape box, rounded to
    /// `DODRadius.standard` so the photo reads as an editorial plate floating on
    /// the borderless-on-light surface.
    @ViewBuilder
    var heroImage: some View {
        switch variant {
        case .classic:
            reliableHero
                .frame(height: 140)
                .clipped()
        case .magazine:
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    reliableHero
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        }
    }

    /// The shared cached-image loader body (DUT-195 — `ReliableImage`, not
    /// `AsyncImage`, which dropped thumbnails on scroll). Framing + clipping are
    /// applied by ``heroImage`` per variant.
    private var reliableHero: some View {
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
    }
}

#Preview("Magazine, with Popular badge") {
    RecipeCard(
        title: "Garlic Butter Skillet Corn",
        excerpt: "An easy 15-minute side dish that pairs with everything.",
        heroImageURL: URL(string: "https://www.dutchovendaddy.com/wp-content/uploads/sample.jpg"),
        totalTimeDisplay: "15 min",
        variant: .magazine,
        popularRank: 1
    )
    .frame(width: 340)
    .padding(DODSpacing.md)
    .background(DODColor.surface)
}

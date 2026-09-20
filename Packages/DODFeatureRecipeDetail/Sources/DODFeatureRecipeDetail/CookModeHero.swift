import DODDesignSystem
import SwiftUI

/// Cook Mode's immersive hero header — the same full-bleed, blur-strip treatment
/// as the recipe page (``RecipeDetailHero``), tuned for the cooking surface.
///
/// The photo reaches the very top of the screen (into the safe area) with a
/// progressive-blur strip under the floating controls so the back / ingredients
/// buttons stay legible over any photo, a soft bottom gradient, and the recipe
/// title overlaid at the bottom. It replaces Cook Mode's old inset rounded
/// "album art" card + separate title bar, which reclaims the header height for
/// the step instructions.
///
/// Shorter than the recipe page's 400pt hero (`baseHeight` 200) so the step text
/// dominates. The hero lives inside the step ScrollView, so it scrolls away on a
/// long step; the back + ingredients buttons float ABOVE it (see
/// ``CookModeView/cookModeTopBar``) and stay pinned.
///
/// The hero ignores the top safe area, so it can't read its own inset; the
/// parent (`CookModeView.body`) reads the real top inset and passes it in.
struct CookModeHero: View {

    let url: URL?
    let title: String
    /// Real top safe-area inset, read at the parent level (the hero ignores
    /// safe area so can't read its own).
    let topInset: CGFloat

    /// Resting hero height below the safe area. The drawn height adds `topInset`
    /// so the photo reaches the top of the screen. Kept compact (recipe page uses
    /// 400) so Cook Mode's step text gets the room.
    private let baseHeight: CGFloat = 200

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            heroImage
                .frame(width: nil, height: baseHeight + topInset)
                .frame(maxWidth: .infinity)
                .clipped()

            // Dark scrim under the blur strip (same mask geometry) so the
            // floating glyphs keep contrast over bright photos.
            Rectangle()
                .fill(.black.opacity(0.28))
                .frame(height: topInset + 52)
                .mask(blurMaskGradient)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            // Progressive blur strip — public API only: a clear rectangle over
            // `.ultraThinMaterial`, masked by a top-to-clear gradient, blurs the
            // band behind the floating controls and fades out below.
            Rectangle()
                .fill(.clear)
                .background(.ultraThinMaterial)
                .mask(blurMaskGradient)
                .frame(height: topInset + 52)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            // Soft bottom gradient so the title reads against any photo.
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            Text(title)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
                .padding(.horizontal, DODSpacing.md)
                .padding(.bottom, DODSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: baseHeight + topInset)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    /// Opaque at the very top (under the floating controls), fading to clear so
    /// the band below is crisp. Shared by the blur strip and its dark scrim.
    private var blurMaskGradient: LinearGradient {
        LinearGradient(
            colors: [.black, .black.opacity(0.6), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var heroImage: some View {
        // T-839 — reliable cached loader (ReliableImage), not AsyncImage, so the
        // hero doesn't stick on the skeleton.
        ReliableImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                // DUT-524 — neutral static placeholder instead of an infinite
                // shimmer when the hero can't load.
                DODColor.surfaceElevated
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 40))
                            .foregroundStyle(DODColor.labelSecondary)
                    )
            case .empty:
                LoadingSkeleton(cornerRadius: 0)
            }
        }
    }
}

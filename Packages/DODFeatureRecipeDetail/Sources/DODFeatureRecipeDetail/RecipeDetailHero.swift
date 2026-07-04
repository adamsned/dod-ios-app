import DODDesignSystem
import SwiftUI

/// DUT-572 / CL-312 — full-bleed, stretchy hero with a progressive-blur strip
/// under the nav bar.
///
/// The image reaches the very top of the screen (into the safe area) and
/// rubber-bands taller on pull-down. A top strip blurs the band behind the
/// toolbar glyphs (public-API `.ultraThinMaterial` masked by a fading
/// `LinearGradient` — NOT the private `variableBlur` CAFilter) so the
/// back / Save / Share / Download buttons stay legible over any photo, fading
/// to a crisp banner below. The existing bottom gradient + overlaid title are
/// kept.
///
/// The hero ignores the top safe area, so it can't read its own inset; the
/// parent (`RecipeDetailView.readyBody`) reads the real top inset and passes it
/// in as `topInset`.
struct RecipeDetailHero: View {

    let url: URL?
    let title: String
    /// Real top safe-area inset, read at the parent level (the hero ignores
    /// safe area so can't read its own).
    let topInset: CGFloat

    /// Resting hero height below the safe area. The effective height grows by
    /// `topInset` (to reach the top of the screen) plus any positive pull-down.
    private let baseHeight: CGFloat = 320

    var body: some View {
        GeometryReader { geo in
            // minY in the named scroll coordinate space: 0 at rest, positive on
            // pull-down (rubber-band), negative once scrolled up. Only the top
            // grows on pull-down — the image is bottom-anchored.
            let minY = geo.frame(in: .named("recipeScroll")).minY
            let stretch = max(0, minY)
            let height = baseHeight + topInset + stretch

            ZStack(alignment: .bottomLeading) {
                heroImage
                    .frame(width: geo.size.width, height: height)
                    .clipped()

                // Faint dark scrim under the blur strip (same mask geometry) so
                // the glyphs keep contrast over bright photos.
                Rectangle()
                    .fill(.black.opacity(0.18))
                    .frame(height: topInset + 56)
                    .mask(blurMaskGradient)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                // Progressive blur strip — public API only. A clear rectangle
                // over `.ultraThinMaterial`, masked by a top-to-clear gradient,
                // blurs the band behind the toolbar and fades out below.
                Rectangle()
                    .fill(.clear)
                    .background(.ultraThinMaterial)
                    .mask(blurMaskGradient)
                    .frame(height: topInset + 56)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                // Soft bottom gradient — covers the lower portion of the hero so
                // the title reads against any photo background.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                Text(title)
                    .dodFont(DODType.displayLarge)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, DODSpacing.md)
                    .padding(.bottom, DODSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geo.size.width, height: height)
            // Bottom-anchor so pull-down only grows the top edge; the image
            // stays pinned to the resting bottom position.
            .offset(y: -stretch)
        }
        .frame(height: baseHeight)
        .ignoresSafeArea(.container, edges: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    /// The mask gradient shared by the blur strip + its dark scrim: opaque at
    /// the very top (under the nav bar), fading to clear so the band below is
    /// crisp.
    private var blurMaskGradient: LinearGradient {
        LinearGradient(
            colors: [.black, .black.opacity(0.6), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var heroImage: some View {
        // T-839 — reliable cached loader (DUT-195's ReliableImage) instead of
        // AsyncImage, which left the detail hero stuck on the skeleton when a
        // load hit a transient error or was cancelled (tester-reported).
        ReliableImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                // DUT-524 — a missing / permanently-failing hero renders a
                // neutral static placeholder (matching the feed-card empty tile)
                // instead of an infinite "loading" shimmer.
                heroFailurePlaceholder
            case .empty:
                LoadingSkeleton(cornerRadius: 0)
            }
        }
    }

    /// DUT-524 — neutral static tile shown when the hero image can't load, so a
    /// missing photo reads as "no image" rather than a perpetual shimmer.
    private var heroFailurePlaceholder: some View {
        DODColor.surfaceElevated
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                Image(systemName: "fork.knife")
                    .font(.system(size: 48))
                    .foregroundStyle(DODColor.labelSecondary)
            )
    }
}

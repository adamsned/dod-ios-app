import DODDesignSystem
import SwiftUI

/// Hero image + bottom gradient + overlaid title for the detail screen.
/// Pulled out of ``RecipeDetailView`` so the parent stays under the
/// per-file line budget.
struct RecipeDetailHero: View {

    let url: URL?
    let title: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // T-839 — reliable cached loader (DUT-195's ReliableImage) instead of
            // AsyncImage, which left the detail hero stuck on the skeleton when a
            // load hit a transient error or was cancelled (tester-reported).
            ReliableImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    // DUT-524 — a missing / permanently-failing hero used to fall
                    // through to `default` and draw the animated skeleton forever
                    // (an infinite "loading" shimmer). Render a neutral static
                    // placeholder instead, matching the app's feed-card empty tile.
                    heroFailurePlaceholder
                case .empty:
                    LoadingSkeleton(cornerRadius: 0)
                }
            }
            .frame(height: 320)
            .clipped()

            // Soft bottom gradient — covers the lower ~40% of the hero so the
            // title reads against any photo background.
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 320)
            .allowsHitTesting(false)

            Text(title)
                .dodFont(DODType.displayLarge)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
                .padding(.horizontal, DODSpacing.md)
                .padding(.bottom, DODSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 320)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
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

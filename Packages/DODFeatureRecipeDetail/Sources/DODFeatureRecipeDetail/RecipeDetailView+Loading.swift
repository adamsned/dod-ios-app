import DODDesignSystem
import SwiftUI

extension RecipeDetailView {
    /// Placeholder shown while the recipe detail loads — a full-bleed hero
    /// skeleton over a few text-line skeletons. Extracted from
    /// `RecipeDetailView` so the main struct's body stays under the SwiftLint
    /// `type_body_length` cap after the T-804 iPad reading-column wrapper.
    var loadingSkeleton: some View {
        ScrollView {
            VStack(spacing: DODSpacing.md) {
                LoadingSkeleton(cornerRadius: 0).frame(height: 280)
                LoadingSkeleton().frame(height: 24).padding(.horizontal, DODSpacing.md)
                LoadingSkeleton().frame(height: 16).padding(.horizontal, DODSpacing.lg)
                LoadingSkeleton().frame(height: 16).padding(.horizontal, DODSpacing.lg)
            }
        }
        .accessibilityLabel("Loading recipe")
    }
}

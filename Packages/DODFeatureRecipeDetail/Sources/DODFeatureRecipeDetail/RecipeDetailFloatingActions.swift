import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Floating save + share buttons anchored to the bottom-right of the detail
/// screen. Remain visible while the user scrolls past the nav bar so the
/// primary actions are always within thumb reach.
struct RecipeDetailFloatingActions: View {

    let isSaved: Bool
    let canonicalURL: URL
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: DODSpacing.sm) {
            // Save haptic is fired by the parent view's
            // .sensoryFeedback(.success, trigger: viewModel.isSaved) so we
            // don't double-fire here.
            Button(
                action: onSave,
                label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(DODColor.accent))
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                }
            )
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Unsave recipe" : "Save recipe")

            ShareLink(item: canonicalURL) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(DODColor.label)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(DODColor.surfaceElevated))
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
            }
            .simultaneousGesture(
                TapGesture().onEnded { onShare() }
            )
            .accessibilityLabel("Share recipe")
        }
    }
}

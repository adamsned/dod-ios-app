import AVKit
import DODDesignSystem
import DODDomain
import SwiftUI

/// "Video" section of the recipe detail (AC-4.4) with an offline placeholder
/// (AC-4.5 / AC-5.5). Extracted into its own file so ``RecipeDetailView``
/// stays under the SwiftLint type-body-length cap.
struct RecipeDetailVideoSection: View {

    let video: RecipeVideo
    let isOfflineSnapshot: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Video")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .padding(.horizontal, DODSpacing.md)
            if isOfflineSnapshot {
                offlinePlaceholder
            } else {
                VideoPlayer(player: AVPlayer(url: video.url))
                    .frame(height: 200)
                    .padding(.horizontal, DODSpacing.md)
            }
        }
    }

    private var offlinePlaceholder: some View {
        RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
            .fill(DODColor.surfaceElevated)
            .frame(height: 200)
            .overlay(
                VStack(spacing: DODSpacing.xs) {
                    Image(systemName: "play.slash")
                        .font(.title)
                        .foregroundStyle(DODColor.labelSecondary)
                    Text("Video unavailable offline")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                }
            )
            .padding(.horizontal, DODSpacing.md)
    }
}

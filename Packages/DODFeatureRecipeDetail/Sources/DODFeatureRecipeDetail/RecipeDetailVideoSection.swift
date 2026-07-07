import AVKit
import DODDesignSystem
import DODDomain
import SwiftUI

#if os(iOS)
import Combine
#endif

#if canImport(UIKit)
import UIKit
#endif

/// "Video" section of the recipe detail (AC-4.4) with an offline placeholder
/// (AC-4.5 / AC-5.5). Extracted into its own file so ``RecipeDetailView`` stays
/// under the SwiftLint type-body-length cap.
///
/// T-805: the player is an `AVPlayerViewController` (system playback controls +
/// fullscreen button + PiP) sized to the video's **real aspect ratio**, read
/// from the asset — so a portrait clip becomes a tall, centered player instead
/// of a wide 200pt box that letterboxes the video with black bars.
struct RecipeDetailVideoSection: View {

    let video: RecipeVideo
    let isOfflineSnapshot: Bool

    /// Caps a portrait clip so it doesn't tower over the page; a landscape clip
    /// fills the column width and lands well under this.
    private static let maxHeight: CGFloat = 440

    @State private var aspectRatio: CGFloat = 16.0 / 9.0
    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Video")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .padding(.horizontal, DODSpacing.md)
            if isOfflineSnapshot {
                offlinePlaceholder
            } else {
                playerBox
            }
        }
    }

    private var playerBox: some View {
        Group {
            if let player {
                RecipeVideoPlayer(player: player)
            } else {
                DODColor.surfaceElevated
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: Self.maxHeight)
        .padding(.horizontal, DODSpacing.md)
        .task(id: video.url) {
            // DUT-632 — do NOT touch the audio session here: creating the player
            // (or scrolling the section into view) must not interrupt the user's
            // background music. We grab the `.playback` session only once
            // playback actually starts (see `.onVideoPlaybackStarted` below).
            if player == nil { player = AVPlayer(url: video.url) }
            if let ratio = await Self.loadAspectRatio(for: video.url) {
                aspectRatio = ratio
            }
        }
        .onVideoPlaybackStateChanged(of: player) { state in
            switch state {
            case .playing:
                // DUT-632 — switch the shared audio session to `.playback` the
                // moment the user actually plays the video, so it's audible even
                // with the hardware silent switch on. The player itself is never
                // muted; the default `.soloAmbient` category was silencing it when
                // the ringer switch was off. Idempotent, so repeats are harmless.
                RecipeVideoAudioSession.activateForPlayback()
            case .paused:
                // DUT-683 — the video paused/ended, so hand the `.playback`
                // session back with `.notifyOthersOnDeactivation` — otherwise the
                // user's background music/podcast, grabbed on the first tap, never
                // resumes. GUARDED inside `deactivate()` to release only a session
                // this video path activated, never a live Voice Mode session.
                RecipeVideoAudioSession.deactivate()
            case .waitingToPlay:
                // Buffering — neither grab nor release; wait for a real play/pause.
                break
            }
        }
    }

    private var offlinePlaceholder: some View {
        RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
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

    /// Read the video's display aspect ratio (width / height) from the asset,
    /// applying the track's preferred transform so a phone-shot portrait clip
    /// reports portrait. Returns nil if the asset has no loadable video track.
    static func loadAspectRatio(for url: URL) async -> CGFloat? {
        let asset = AVURLAsset(url: url)
        guard
            let track = try? await asset.loadTracks(withMediaType: .video).first,
            let (naturalSize, transform) = try? await track.load(.naturalSize, .preferredTransform)
        else { return nil }
        let displaySize = naturalSize.applying(transform)
        let width = abs(displaySize.width)
        let height = abs(displaySize.height)
        guard width > 0, height > 0 else { return nil }
        return width / height
    }
}

extension View {
    /// DUT-632 / DUT-683 — run `action` with the player's playback state whenever
    /// `player` transitions between paused / buffering / playing. On iOS we
    /// observe the player's `timeControlStatus` via its KVO publisher and map each
    /// status onto ``RecipeVideoAudioSession/PlaybackState`` so the call site can
    /// grab the audio session on `.playing` and release it on `.paused`. Off iOS
    /// this is a no-op — the package builds for the macOS host in `swift test`,
    /// where the audio session (and these side effects) don't apply.
    @ViewBuilder
    func onVideoPlaybackStateChanged(
        of player: AVPlayer?,
        perform action: @escaping (RecipeVideoAudioSession.PlaybackState) -> Void
    ) -> some View {
        #if os(iOS)
        if let player {
            onReceive(player.publisher(for: \.timeControlStatus)) { status in
                action(RecipeVideoAudioSession.playbackState(from: status))
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if canImport(UIKit)
/// Native `AVPlayerViewController` wrapper — system playback controls, the
/// fullscreen button, and PiP (AC-4.4). `videoGravity = .resizeAspect` fills
/// the already-aspect-correct container, so there's no in-player letterbox.
private struct RecipeVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }
}
#else
/// macOS fallback (the package builds for the host in `swift test`): SwiftUI's
/// `VideoPlayer` keeps the section compiling where `AVPlayerViewController`
/// (UIKit) isn't available.
private struct RecipeVideoPlayer: View {
    let player: AVPlayer
    var body: some View { VideoPlayer(player: player) }
}
#endif

import SwiftUI

#if canImport(UIKit)
import AVFoundation
import UIKit
#endif

/// A reference to a bundled looping clip for the App Intro media area.
///
/// This is deliberately thin: it wraps a resolved file `URL` (nil when the
/// resource is missing), which keeps ``AppIntroTour/Page`` `Sendable` and lets a
/// caller point at *any* clip.
///
/// ## Swapping in a real clip
///
/// The prototype ships one bundled placeholder, ``placeholder``. To drop in a
/// real, professionally-produced `.mov` later:
///
/// 1. Add the file to a bundle you control (the app target, or this package's
///    `Resources/` dir if it should live in the design system).
/// 2. Point a source at it, e.g. from the app target:
///    ```swift
///    IntroVideoSource(url: Bundle.main.url(
///        forResource: "cook-mode-demo", withExtension: "mov"))
///    ```
///    or add another `static let` beside ``placeholder`` for a package resource.
/// 3. Attach it to the relevant ``AppIntroTour/Page`` via its `video:` argument.
///
/// Clips should be short, seamless-looping (last frame ≈ first frame),
/// **muted / no audio track**, and HEVC for size. `LoopingVideoView` never
/// touches `AVAudioSession`, so a stray audio track would still be silenced —
/// but stripping it keeps files small.
public struct IntroVideoSource: Sendable {
    /// The resolved clip location. `nil` → the view shows its poster fallback.
    public let url: URL?

    /// `true` for an **HEVC-with-alpha** clip whose background is transparent
    /// (e.g. a device-framed screen recording floating on the slide). The view
    /// then drops its card fill and composites the clip over the slide's OWN
    /// background — Flour in light, Cocoa in dark — so one clip works in both
    /// modes. Transparent clips are shown aspect-fit (not fill) so the whole
    /// floating subject stays visible and uncropped.
    public let isTransparent: Bool

    public init(url: URL?, isTransparent: Bool = false) {
        self.url = url
        self.isTransparent = isTransparent
    }

    /// The bundled burnt-orange → warm-cream placeholder clip shipped inside
    /// DODDesignSystem (`intro-placeholder.mov`). Swap per-slide clips in via a
    /// real file — see the type doc above.
    public static let placeholder = IntroVideoSource(
        url: Bundle.module.url(forResource: "intro-placeholder", withExtension: "mov")
    )
}

/// Plays a bundled clip on a **seamless, gapless loop** in the App Intro media
/// area, sized to match the SF-symbol placeholder it replaces.
///
/// Design notes:
/// - **Gapless loop** via `AVQueuePlayer` + `AVPlayerLooper` (not seek-to-zero,
///   which stutters at the wrap).
/// - **Silent + ambient**: the player is muted and the view *never* configures
///   `AVAudioSession`, so it can't interrupt the user's music/podcast.
/// - **Play only when visible**: driven by `isActive` — the tour passes
///   `index == thisPageOffset`, so off-screen slides pause and rewind.
/// - **Reduce Motion**: when the user has Reduce Motion on, the loop is replaced
///   by a static poster (the slide's SF-symbol) — no autoplaying motion.
/// - **Light / dark**: the container + poster use design-system tokens
///   (`surfaceElevated`, `accent`), which carry their own light/dark variants.
/// - **macOS / no-UIKit**: AVKit is `#if canImport(UIKit)`-guarded; the L1
///   `swift test` slice compiles the poster-only path.
public struct LoopingVideoView: View {

    private let source: IntroVideoSource
    private let isActive: Bool
    private let posterSymbol: String

    /// - Parameters:
    ///   - source: the clip to loop (see ``IntroVideoSource``).
    ///   - isActive: play when `true`; pause + rewind when `false`.
    ///   - posterSymbol: SF Symbol shown when motion is unavailable (Reduce
    ///     Motion, a missing file, or the non-UIKit build).
    public init(source: IntroVideoSource, isActive: Bool, posterSymbol: String) {
        self.source = source
        self.isActive = isActive
        self.posterSymbol = posterSymbol
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fall back to the static poster when motion is off, the file is missing,
    /// or AVKit isn't available (macOS L1 slice).
    private var showsPoster: Bool {
        #if canImport(UIKit)
        return reduceMotion || source.url == nil
        #else
        return true
        #endif
    }

    public var body: some View {
        ZStack {
            // Opaque clips sit on an elevated card. A transparent (HEVC-alpha)
            // clip drops the fill so the slide's own background shows through the
            // alpha and the framed subject floats.
            if !source.isTransparent {
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .fill(DODColor.surfaceElevated)
            }
            media
        }
        .aspectRatio(0.62, contentMode: .fit)
        .frame(maxWidth: 260)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        // Matches the SF-symbol placeholder: decorative, so hide it from
        // VoiceOver (the slide's title + description carry the meaning).
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var media: some View {
        if showsPoster {
            Image(systemName: posterSymbol)
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(DODColor.accent)
        } else {
            #if canImport(UIKit)
            LoopingPlayerRepresentable(
                url: source.url,
                isActive: isActive,
                isTransparent: source.isTransparent
            )
            #endif
        }
    }
}

#if canImport(UIKit)

/// Bridges the looping `AVPlayerLayer`-backed view into SwiftUI, forwarding the
/// `isActive` play/pause signal on updates.
private struct LoopingPlayerRepresentable: UIViewRepresentable {
    let url: URL?
    let isActive: Bool
    let isTransparent: Bool

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: url, isTransparent: isTransparent)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: Coordinator) {
        uiView.stop()
    }
}

/// An `AVPlayerLayer`-backed `UIView` that loops a clip gaplessly and silently.
/// Retains the `AVPlayerLooper` (which otherwise deallocates and stops the loop).
private final class LoopingPlayerUIView: UIView {

    private let playerLayer = AVPlayerLayer()
    private let queuePlayer = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL?, isTransparent: Bool) {
        super.init(frame: .zero)

        // Muted + never touching AVAudioSession → strictly ambient; the clip
        // can't duck or interrupt the user's audio. (Placeholder has no audio
        // track anyway; this keeps that guarantee for any real clip too.)
        queuePlayer.isMuted = true
        queuePlayer.preventsDisplaySleepDuringVideoPlayback = false
        playerLayer.player = queuePlayer
        // Transparent (HEVC-alpha) clips: fit the whole framed subject and let
        // the slide background composite through the alpha (needs a non-opaque,
        // clear-backed layer). Opaque clips fill the media box.
        if isTransparent {
            playerLayer.videoGravity = .resizeAspect
            isOpaque = false
            backgroundColor = .clear
            playerLayer.backgroundColor = UIColor.clear.cgColor
        } else {
            playerLayer.videoGravity = .resizeAspectFill
        }
        layer.addSublayer(playerLayer)

        if let url {
            let item = AVPlayerItem(url: url)
            // AVPlayerLooper drives the seamless wrap (no seek-to-zero seam).
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    /// Play when the slide is visible; pause + rewind when it scrolls away so
    /// only the on-screen slide animates.
    func setActive(_ active: Bool) {
        if active {
            queuePlayer.play()
        } else {
            queuePlayer.pause()
            queuePlayer.seek(to: .zero)
        }
    }

    /// Tear down on dismantle so nothing keeps ticking behind a dismissed tour.
    func stop() {
        queuePlayer.pause()
        looper?.disableLooping()
        looper = nil
        queuePlayer.removeAllItems()
    }
}

#endif

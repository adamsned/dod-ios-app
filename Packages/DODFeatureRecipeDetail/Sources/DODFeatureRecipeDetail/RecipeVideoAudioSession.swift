import Foundation

#if os(iOS)
import AVFoundation
#endif

/// DUT-632 — makes a recipe video audible.
///
/// The recipe video plays through an `AVPlayerViewController` that is never
/// muted (no `isMuted`/`volume` override), yet users heard no sound. The cause
/// is the app's shared `AVAudioSession`: its default `.soloAmbient`/`.ambient`
/// category obeys the hardware silent switch, so a recipe video is silenced
/// whenever the ringer switch is on. Setting the category to `.playback` makes
/// the video audible even with the silent switch on — the same posture
/// ``VoiceReader`` uses for Cook Mode's Voice Mode (AC-40.6).
///
/// Unlike Voice Mode we do NOT `.duckOthers`: a recipe video is foreground
/// content the user tapped to watch, so background audio should stop, not dip.
/// We also don't force-deactivate on disappear — tearing the session down while
/// Voice Mode may hold it open (they share the app's one session) would fight
/// Cook Mode. Leaving a `.playback` session in place is benign; the app already
/// tolerates it after every Voice Mode read.
enum RecipeVideoAudioSession {

    /// The category/mode/options a recipe video needs to be audible.
    ///
    /// Factored out as a pure value so the decision is unit-testable on macOS,
    /// where `AVAudioSession` (iOS-only) can't be activated hermetically.
    struct Configuration: Equatable {
        /// `.playback` so video audio is heard even with the silent switch on.
        let categoryIsPlayback: Bool
        /// Video is foreground content the user chose to watch, so background
        /// audio should stop rather than duck — no `.duckOthers`.
        let ducksOthers: Bool

        static let forRecipeVideo = Configuration(
            categoryIsPlayback: true,
            ducksOthers: false
        )
    }

    /// Activate a `.playback` session so a recipe video is audible even with the
    /// hardware silent switch on. No-op off iOS. A failed activation must never
    /// break playback (the video still plays, just possibly muted by the switch),
    /// so errors are swallowed — matching ``VoiceReader``'s posture.
    static func activateForPlayback() {
        #if os(iOS)
        let config = Configuration.forRecipeVideo
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                config.categoryIsPlayback ? .playback : .ambient,
                mode: .moviePlayback,
                options: config.ducksOthers ? [.duckOthers] : []
            )
            try session.setActive(true)
        } catch {
            // Swallow: a failed audio-session activation must never break video
            // playback. The video still renders; audio just follows the switch.
        }
        #endif
    }
}

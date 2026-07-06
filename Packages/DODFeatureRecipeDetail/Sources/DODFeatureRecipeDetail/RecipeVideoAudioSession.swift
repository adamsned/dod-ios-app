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
///
/// DUT-632 (follow-up) — we activate only when playback actually STARTS, not
/// when the player/section appears. `setActive(true)` on a non-mixing
/// `.playback` session interrupts the user's background music, so activating on
/// mere creation would stop their music just for scrolling past a video they
/// never tapped. The view watches the player's `timeControlStatus` and calls
/// ``activateForPlayback()`` on the transition to playing (see
/// ``shouldActivate(for:)``); repeat calls are harmless (idempotent).
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

    /// The playback states a video can be in, mapped from `AVPlayer`'s
    /// `AVPlayer.TimeControlStatus` at the call site. Pure and platform-free so
    /// the "activate now?" decision is unit-testable on the macOS host.
    enum PlaybackState {
        case paused
        case waitingToPlay
        case playing
    }

    /// True only when the player has actually started playing — the moment we
    /// want to grab the `.playback` session. We deliberately do NOT activate for
    /// `.waitingToPlay` (buffering can occur before the user ever hears audio)
    /// or `.paused`, so merely showing/creating the player never interrupts the
    /// user's background music.
    static func shouldActivate(for state: PlaybackState) -> Bool {
        state == .playing
    }

    /// Activate a `.playback` session so a recipe video is audible even with the
    /// hardware silent switch on. No-op off iOS. A failed activation must never
    /// break playback (the video still plays, just possibly muted by the switch),
    /// so errors are swallowed — matching ``VoiceReader``'s posture. Idempotent:
    /// safe to call on every transition to playing.
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

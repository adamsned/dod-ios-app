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
///
/// DUT-683 — the `.playback` session (no `.mixWithOthers`) grabs the user's
/// background music/podcast on the first video tap and, on the original video
/// path, was NEVER handed back: the session stayed activated after the clip
/// paused/ended, so other apps' audio couldn't resume (unless the cook later
/// used Voice Mode, whose own release path happened to deactivate it). We now
/// call ``deactivate()`` when the video pauses/ends, releasing the session with
/// `.notifyOthersOnDeactivation` so background audio resumes promptly.
///
/// GUARD — Voice Mode (``VoiceReader``) shares the app's one `AVAudioSession`.
/// We must never tear down a live Voice Mode session. There is no shared
/// "who owns the session" flag across the two paths, so we deactivate ONLY the
/// session this video path itself activated: ``deactivate()`` no-ops unless our
/// own ``didActivate`` flag is set, and that flag is only set by a successful
/// ``activateForPlayback()``. If Voice Mode owns the session, this path never
/// activated it, so ``didActivate`` is false and ``deactivate()`` stands down.
enum RecipeVideoAudioSession {

    /// DUT-683 — true only while THIS video path holds the `.playback` session
    /// it activated. Guards ``deactivate()`` so a video pause/end never releases
    /// a session this path didn't open (e.g. one Voice Mode owns). Mutated only
    /// on the main actor at the SwiftUI call sites; `nonisolated(unsafe)` because
    /// the enum is a namespace, not an actor. Reset to false on release.
    nonisolated(unsafe) private static var didActivate = false

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
    enum PlaybackState: Equatable {
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

    #if os(iOS)
    /// Map `AVPlayer`'s `timeControlStatus` onto our platform-free
    /// ``PlaybackState`` at the call site (DUT-683). iOS-only: `AVPlayer` isn't
    /// used for this decision on the macOS test host.
    static func playbackState(from status: AVPlayer.TimeControlStatus) -> PlaybackState {
        switch status {
        case .paused: .paused
        case .waitingToPlayAtSpecifiedRate: .waitingToPlay
        case .playing: .playing
        @unknown default: .paused
        }
    }
    #endif

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
            // DUT-683 — record that WE activated the session so a later
            // ``deactivate()`` knows this path owns it and may release it.
            didActivate = true
        } catch {
            // Swallow: a failed audio-session activation must never break video
            // playback. The video still renders; audio just follows the switch.
        }
        #endif
    }

    /// DUT-683 — release the `.playback` session when the video pauses/ends so
    /// the user's background music/podcast resumes. No-op off iOS. GUARDED on
    /// ``didActivate`` so it only ever releases a session THIS video path
    /// activated — never one Voice Mode (``VoiceReader``) owns, since in that
    /// case this path never activated and the flag is false. Uses
    /// `.notifyOthersOnDeactivation` so other apps' audio un-pauses promptly.
    /// Idempotent: safe to call on every transition to paused.
    static func deactivate() {
        #if os(iOS)
        // Only release what this path activated — never Voice Mode's session.
        guard didActivate else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
            // Clear only on SUCCESS. `setActive(false)` can throw while audio I/O
            // is still winding down; keeping the flag set lets the next pause/end
            // retry rather than stranding the session activated forever.
            didActivate = false
        } catch {
            // Flag stays set; the next deactivate attempt retries.
        }
        #endif
    }
}

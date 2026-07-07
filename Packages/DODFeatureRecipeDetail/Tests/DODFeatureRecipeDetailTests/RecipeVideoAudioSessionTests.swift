import Testing

#if os(iOS)
import AVFoundation
#endif

@testable import DODFeatureRecipeDetail

/// L1 unit coverage for `RecipeVideoAudioSession.Configuration` — the pure,
/// platform-free decision of which audio-session posture a recipe video needs.
///
/// The real `AVAudioSession` activation is iOS-only and can't be exercised
/// hermetically on the macOS test host, so we test the decision value instead:
/// a recipe video must use `.playback` (audible over the silent switch) and
/// must NOT duck other audio (it's foreground content the user tapped).
///
/// Spec trace: DUT-632.
@Suite("RecipeVideoAudioSession.Configuration (DUT-632)")
struct RecipeVideoAudioSessionTests {

    @Test("recipe video uses .playback so it's audible over the silent switch")
    func recipeVideoUsesPlayback() {
        #expect(RecipeVideoAudioSession.Configuration.forRecipeVideo.categoryIsPlayback)
    }

    @Test("recipe video does not duck other audio (foreground content)")
    func recipeVideoDoesNotDuck() {
        #expect(RecipeVideoAudioSession.Configuration.forRecipeVideo.ducksOthers == false)
    }

    @Test("configuration is a stable value")
    func configurationEquatable() {
        #expect(
            RecipeVideoAudioSession.Configuration.forRecipeVideo
                == RecipeVideoAudioSession.Configuration(categoryIsPlayback: true, ducksOthers: false)
        )
    }

    // DUT-632 (follow-up) — we grab the `.playback` session only once playback
    // actually starts, never on mere creation/appear, so scrolling past a video
    // doesn't interrupt the user's background music.

    @Test("activate only when the video is actually playing")
    func activatesOnPlaying() {
        #expect(RecipeVideoAudioSession.shouldActivate(for: .playing))
    }

    @Test("do not activate while paused (e.g. on creation/appear)")
    func doesNotActivateWhilePaused() {
        #expect(RecipeVideoAudioSession.shouldActivate(for: .paused) == false)
    }

    @Test("do not activate while merely buffering to play")
    func doesNotActivateWhileWaiting() {
        #expect(RecipeVideoAudioSession.shouldActivate(for: .waitingToPlay) == false)
    }

    // DUT-683 — the video path now releases the shared `.playback` session when
    // the clip pauses/ends so the user's background audio resumes. The real
    // `AVAudioSession` release is iOS-only and can't run hermetically on the
    // macOS host, so we test the platform-free decision: the `timeControlStatus`
    // → `PlaybackState` mapping the section switches on to activate vs. release.

    #if os(iOS)
    @Test("paused status maps to .paused (the release trigger)")
    func pausedStatusMapsToPaused() {
        #expect(RecipeVideoAudioSession.playbackState(from: .paused) == .paused)
    }

    @Test("playing status maps to .playing (the activate trigger)")
    func playingStatusMapsToPlaying() {
        #expect(RecipeVideoAudioSession.playbackState(from: .playing) == .playing)
    }

    @Test("buffering status maps to .waitingToPlay (neither grab nor release)")
    func waitingStatusMapsToWaiting() {
        #expect(
            RecipeVideoAudioSession.playbackState(from: .waitingToPlayAtSpecifiedRate)
                == .waitingToPlay
        )
    }
    #endif
}

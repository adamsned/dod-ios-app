import Testing

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
}

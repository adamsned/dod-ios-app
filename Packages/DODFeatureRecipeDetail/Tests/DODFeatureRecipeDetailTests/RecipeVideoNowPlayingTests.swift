import Testing

@testable import DODFeatureRecipeDetail

#if os(iOS)
import MediaPlayer
#endif

@Suite("RecipeVideoNowPlaying (DUT-1013)")
struct RecipeVideoNowPlayingTests {
    @Test func playbackRate() {
        // playbackRate is 1.0 when isPlaying is true and 0.0 when false
        let playing = RecipeVideoNowPlaying(title: "Test", elapsed: 10, duration: nil, isPlaying: true)
        #expect(playing.playbackRate == 1.0)

        let paused = RecipeVideoNowPlaying(title: "Test", elapsed: 10, duration: nil, isPlaying: false)
        #expect(paused.playbackRate == 0.0)
    }

    @Test func clampedElapsed() {
        // clampedElapsed returns 0 for a negative value and for .nan
        let negative = RecipeVideoNowPlaying(title: "Test", elapsed: -5, duration: nil, isPlaying: true)
        #expect(negative.clampedElapsed == 0)

        let nan = RecipeVideoNowPlaying(title: "Test", elapsed: .nan, duration: nil, isPlaying: true)
        #expect(nan.clampedElapsed == 0)

        // clampedElapsed returns the duration when elapsed is greater than it
        let exceedingDuration = RecipeVideoNowPlaying(title: "Test", elapsed: 20, duration: 15, isPlaying: true)
        #expect(exceedingDuration.clampedElapsed == 15)

        // clampedElapsed returns elapsed when no duration is set
        let noDuration = RecipeVideoNowPlaying(title: "Test", elapsed: 10, duration: nil, isPlaying: true)
        #expect(noDuration.clampedElapsed == 10)
    }

    #if os(iOS)
    @Test func infoDictionaryCarriesTitleAndRate() {
        let video = RecipeVideoNowPlaying(title: "Brisket", elapsed: 12, duration: 60, isPlaying: true)
        #expect(video.infoDictionary[MPMediaItemPropertyTitle] as? String == "Brisket")
        #expect(video.infoDictionary[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1.0)
        #expect(video.infoDictionary[MPMediaItemPropertyPlaybackDuration] as? TimeInterval == 60)
    }
    #endif
}

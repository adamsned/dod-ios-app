#if canImport(MediaPlayer)
import MediaPlayer
import Testing

@testable import DODFeatureRecipeDetail

@Suite struct SystemNowPlayingPublisherTests {
    @Test func infoMapsSnapshotFields() {
        let snapshot = NowPlayingSnapshot(
            state: .playing,
            title: "Step 3 of 8",
            subtitle: "Brisket",
            stepIndex: 2,
            stepCount: 8,
            playbackRate: 1.0
        )
        let info = SystemNowPlayingPublisher.info(for: snapshot)
        #expect(info[MPMediaItemPropertyTitle] as? String == "Step 3 of 8")
        #expect(info[MPMediaItemPropertyArtist] as? String == "Brisket")
        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1.0)
        #expect(info[MPNowPlayingInfoPropertyChapterNumber] as? Int == 2)
        #expect(info[MPNowPlayingInfoPropertyChapterCount] as? Int == 8)
    }

    #if os(iOS)
    @Test @MainActor func activateThenDeactivateLeavesNoTargets() {
        let publisher = SystemNowPlayingPublisher()
        publisher.activate { _ in }
        publisher.deactivate()
        #expect(MPNowPlayingInfoCenter.default().nowPlayingInfo == nil)
        #expect(publisher.targets.isEmpty)
    }
    #endif
}
#endif

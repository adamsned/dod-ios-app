import Testing

@testable import DODFeatureRecipeDetail

@Suite struct NowPlayingSnapshotTests {
    private func makeSnapshot(state: NowPlayingSnapshot.State = .playing) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            state: state,
            title: "Step 3 of 8",
            subtitle: "Brisket",
            stepIndex: 2,
            stepCount: 8,
            playbackRate: 1.0
        )
    }

    @Test func equalSnapshotsAreEqual() {
        #expect(makeSnapshot() == makeSnapshot())
    }

    @Test func differentStateIsNotEqual() {
        #expect(makeSnapshot(state: .playing) != makeSnapshot(state: .paused))
    }

    @Test func remoteCommandsAreHashable() {
        let all: Set<NowPlayingRemoteCommand> = [
            .play, .pause, .togglePlayPause, .nextStep, .previousStep, .replayStep,
        ]
        #expect(all.count == 6)
    }
}

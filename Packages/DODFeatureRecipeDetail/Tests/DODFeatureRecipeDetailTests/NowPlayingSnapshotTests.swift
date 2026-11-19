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

    @Test @MainActor func fakePublisherRoutesCommandsAndPublishes() {
        let fake = FakeNowPlayingPublisher()
        let publisher: any NowPlayingPublishing = fake
        var received: [NowPlayingRemoteCommand] = []
        publisher.activate { received.append($0) }
        fake.handler?(.nextStep)
        publisher.publish(makeSnapshot())
        publisher.deactivate()
        #expect(received == [.nextStep])
        #expect(fake.published.count == 1)
        #expect(fake.deactivateCount == 1)
        #expect(fake.handler == nil)
    }
}

@MainActor
private final class FakeNowPlayingPublisher: NowPlayingPublishing {
    var handler: (@MainActor (NowPlayingRemoteCommand) -> Void)?
    var published: [NowPlayingSnapshot] = []
    var deactivateCount = 0

    func activate(onCommand: @escaping @MainActor (NowPlayingRemoteCommand) -> Void) {
        handler = onCommand
    }

    func publish(_ snapshot: NowPlayingSnapshot) { published.append(snapshot) }

    func deactivate() {
        handler = nil
        deactivateCount += 1
    }
}

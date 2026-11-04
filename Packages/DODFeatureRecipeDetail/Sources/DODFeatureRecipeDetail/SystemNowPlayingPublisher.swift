#if canImport(MediaPlayer)
import Foundation
import MediaPlayer

/// DUT-1012 - publishes Voice Mode step progress to the system Now Playing surface.
@MainActor
public final class SystemNowPlayingPublisher: NowPlayingPublishing {
    private var onCommand: (@MainActor (NowPlayingRemoteCommand) -> Void)?
    var targets: [(command: MPRemoteCommand, token: Any)] = []

    public init() {}

    public func activate(onCommand: @escaping @MainActor (NowPlayingRemoteCommand) -> Void) {
        deactivate()
        self.onCommand = onCommand
        #if os(iOS)
        let center = MPRemoteCommandCenter.shared()
        func bind(_ command: MPRemoteCommand, _ mapped: NowPlayingRemoteCommand) {
            command.isEnabled = true
            let token = command.addTarget { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let handler = self?.onCommand else { return .noActionableNowPlayingItem }
                    handler(mapped)
                    return .success
                }
            }
            targets.append((command, token))
        }
        bind(center.playCommand, .play)
        bind(center.pauseCommand, .pause)
        bind(center.togglePlayPauseCommand, .togglePlayPause)
        bind(center.nextTrackCommand, .nextStep)
        bind(center.previousTrackCommand, .previousStep)
        // Skip-back 10s is the closest transport glyph to "say that again".
        center.skipBackwardCommand.preferredIntervals = [10]
        bind(center.skipBackwardCommand, .replayStep)
        #endif
    }

    public func publish(_ snapshot: NowPlayingSnapshot) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = Self.info(for: snapshot)
    }

    public func deactivate() {
        for (command, token) in targets {
            command.removeTarget(token)
        }
        targets.removeAll()
        onCommand = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    nonisolated static func info(for snapshot: NowPlayingSnapshot) -> [String: Any] {
        [
            MPMediaItemPropertyTitle: snapshot.title,
            MPMediaItemPropertyArtist: snapshot.subtitle,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.playbackRate,
            MPNowPlayingInfoPropertyChapterNumber: snapshot.stepIndex,
            MPNowPlayingInfoPropertyChapterCount: snapshot.stepCount,
        ]
    }
}
#endif

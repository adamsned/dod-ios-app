import Foundation

/// DUT-1013 — pure description of what the Lock Screen / CarPlay Now Playing
/// card shows for a recipe video. Platform-free so it is testable on macOS.
struct RecipeVideoNowPlaying: Equatable {
    let title: String
    let elapsed: TimeInterval
    let duration: TimeInterval?
    let isPlaying: Bool
    /// 1.0 while playing, 0.0 while paused or buffering.
    var playbackRate: Double { isPlaying ? 1.0 : 0.0 }
    /// Elapsed clamped to >= 0, and to duration when known. NaN or infinite gives 0.
    var clampedElapsed: TimeInterval {
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        if let duration, duration.isFinite, duration > 0 { return min(elapsed, duration) }
        return elapsed
    }
}

#if os(iOS)
import MediaPlayer

extension RecipeVideoNowPlaying {
    /// The dictionary assigned to `MPNowPlayingInfoCenter.default().nowPlayingInfo`.
    var infoDictionary: [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: clampedElapsed,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
        ]
        if let duration, duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        return info
    }

    /// Publish to Lock Screen / CarPlay Now Playing.
    func publish() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = infoDictionary
    }

    /// Remove the Now Playing card (video left the screen).
    static func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
#endif

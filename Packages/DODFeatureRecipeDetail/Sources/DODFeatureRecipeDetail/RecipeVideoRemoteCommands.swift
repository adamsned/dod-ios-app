import AVFoundation
import Foundation

#if os(iOS)
import MediaPlayer
#endif

/// DUT-1013 — transport controls for the recipe video on Lock Screen / CarPlay.
enum RecipeVideoRemoteCommands {
    static let skipInterval: TimeInterval = 15

    /// Pure: where a skip lands, clamped to 0...duration (duration optional).
    static func skipTarget(current: TimeInterval, delta: TimeInterval, duration: TimeInterval?) -> TimeInterval {
        let raw = max(0, current + delta)
        if let duration, duration.isFinite, duration > 0 { return min(raw, duration) }
        return raw
    }

    #if os(iOS)
    nonisolated(unsafe) private static var targets: [Any] = []

    /// Register handlers on MPRemoteCommandCenter. Idempotent: removes earlier targets first.
    @MainActor
    static func register(for player: AVPlayer) {
        unregister()

        let center = MPRemoteCommandCenter.shared()

        // Play command
        center.playCommand.isEnabled = true
        let playTarget = center.playCommand.addTarget { _ in
            player.play()
            return .success
        }
        targets.append(playTarget)

        // Pause command
        center.pauseCommand.isEnabled = true
        let pauseTarget = center.pauseCommand.addTarget { _ in
            player.pause()
            return .success
        }
        targets.append(pauseTarget)

        // Skip forward command
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
        let skipForwardTarget = center.skipForwardCommand.addTarget { _ in
            let current = player.currentTime().seconds
            let duration = player.currentItem?.duration.seconds
            let targetTime = skipTarget(current: current, delta: skipInterval, duration: duration)
            player.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
            return .success
        }
        targets.append(skipForwardTarget)

        // Skip backward command
        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
        let skipBackwardTarget = center.skipBackwardCommand.addTarget { _ in
            let current = player.currentTime().seconds
            let duration = player.currentItem?.duration.seconds
            let targetTime = skipTarget(current: current, delta: -skipInterval, duration: duration)
            player.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
            return .success
        }
        targets.append(skipBackwardTarget)

        // Change playback position command
        center.changePlaybackPositionCommand.isEnabled = true
        let positionTarget = center.changePlaybackPositionCommand.addTarget { event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 600))
                return .success
            }
            return .commandFailed
        }
        targets.append(positionTarget)
    }

    @MainActor
    static func unregister() {
        let center = MPRemoteCommandCenter.shared()

        // Remove all targets
        for target in targets {
            center.playCommand.removeTarget(target)
            center.pauseCommand.removeTarget(target)
            center.skipForwardCommand.removeTarget(target)
            center.skipBackwardCommand.removeTarget(target)
            center.changePlaybackPositionCommand.removeTarget(target)
        }

        // Clear targets and disable commands
        targets.removeAll()
        center.playCommand.isEnabled = false
        center.pauseCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
    }
    #endif
}

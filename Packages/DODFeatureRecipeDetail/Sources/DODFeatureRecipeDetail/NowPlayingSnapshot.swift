import Foundation

/// DUT-1012 - what Voice Mode publishes to the system Now Playing surface.
public struct NowPlayingSnapshot: Equatable, Sendable {
    public enum State: Equatable, Sendable { case playing, paused, stopped }

    public let state: State
    /// e.g. "Step 3 of 8"
    public let title: String
    /// Recipe title.
    public let subtitle: String
    public let stepIndex: Int
    public let stepCount: Int
    /// 1.0 when playing at normal speed, 0 when paused/stopped.
    public let playbackRate: Double

    public init(
        state: State,
        title: String,
        subtitle: String,
        stepIndex: Int,
        stepCount: Int,
        playbackRate: Double
    ) {
        self.state = state
        self.title = title
        self.subtitle = subtitle
        self.stepIndex = stepIndex
        self.stepCount = stepCount
        self.playbackRate = playbackRate
    }
}

/// Transport commands the system can send back (Lock Screen, Control Center, CarPlay, Watch).
public enum NowPlayingRemoteCommand: Sendable, Hashable {
    case play, pause, togglePlayPause, nextStep, previousStep, replayStep
}

/// Seam over the system Now Playing surface so the view model is testable.
@MainActor
public protocol NowPlayingPublishing: AnyObject {
    /// Begin receiving remote commands; `onCommand` is invoked on the main actor.
    func activate(onCommand: @escaping @MainActor (NowPlayingRemoteCommand) -> Void)
    func publish(_ snapshot: NowPlayingSnapshot)
    /// Clear the Now Playing info and remove command targets.
    func deactivate()
}

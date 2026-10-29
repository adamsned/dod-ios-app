import Foundation

public enum FireCircleEvent: Sendable, Equatable {
    case received(FireCircleCook)
    case peerLeft(peerID: String)
}

@MainActor
public protocol FireCircleTransport: AnyObject {
    var isRunning: Bool { get }
    /// Number of currently connected peers.
    var connectedPeerCount: Int { get }
    /// Start advertising + browsing and begin delivering events.
    func start(
        localPeerID: String,
        displayName: String,
        onEvent: @escaping @MainActor (FireCircleEvent) -> Void
    )
    func stop()
    /// Send to all connected peers; no-op when none are connected.
    func broadcast(_ cook: FireCircleCook)
}

/// Test double: records broadcasts, lets tests inject events.
@MainActor
public final class FakeFireCircleTransport: FireCircleTransport {
    public private(set) var isRunning = false
    public var connectedPeerCount = 0
    public private(set) var broadcasts: [FireCircleCook] = []
    private var onEvent: (@MainActor (FireCircleEvent) -> Void)?

    public init() {}

    public func start(
        localPeerID: String,
        displayName: String,
        onEvent: @escaping @MainActor (FireCircleEvent) -> Void
    ) {
        isRunning = true
        self.onEvent = onEvent
    }

    public func stop() {
        isRunning = false
        onEvent = nil
    }

    public func broadcast(_ cook: FireCircleCook) {
        broadcasts.append(cook)
    }

    public func simulate(_ event: FireCircleEvent) {
        onEvent?(event)
    }
}

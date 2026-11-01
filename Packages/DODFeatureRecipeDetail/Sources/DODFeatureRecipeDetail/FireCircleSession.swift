import DODCookActivity
import DODSupport
import Foundation
import Observation

/// DUT-2003 - mirrors the local cook onto the Fire Circle transport and
/// exposes the merged board of every peer's cook.
@Observable
@MainActor
public final class FireCircleSession {
    public private(set) var board = FireCircleBoard()
    public private(set) var isOn = false

    private let transport: any FireCircleTransport
    private let localPeerID: String
    private let cookName: String
    private let now: () -> Date

    public init(
        transport: any FireCircleTransport,
        localPeerID: String = UUID().uuidString,
        cookName: String,
        now: @escaping () -> Date = Date.init
    ) {
        self.transport = transport
        self.localPeerID = localPeerID
        self.cookName = cookName
        self.now = now
    }

    public func join() {
        guard !isOn else { return }
        isOn = true
        transport.start(localPeerID: localPeerID, displayName: cookName) { [weak self] event in
            self?.handle(event)
        }
    }

    public func leave() {
        isOn = false
        transport.stop()
        board = FireCircleBoard()
    }

    /// Call from the same places that call `liveActivity.start/update`.
    public func publish(
        attributes: CookActivityAttributes,
        state: CookActivityAttributes.ContentState
    ) {
        guard isOn else { return }
        transport.broadcast(
            FireCircleCook(
                peerID: localPeerID,
                cookName: cookName,
                recipeTitle: attributes.recipeTitle,
                stepText: state.stepText,
                remainingSeconds: state.remainingSeconds,
                endDate: state.endDate,
                isPaused: state.isPaused,
                isCompleted: state.isCompleted,
                sentAt: now()
            )
        )
    }

    private func handle(_ event: FireCircleEvent) {
        switch event {
        case .received(let cook): board.apply(cook)
        case .peerLeft(let peerID): board.remove(peerID: peerID)
        }
    }
}

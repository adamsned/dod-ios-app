import Foundation
import Testing

@testable import DODSupport

@MainActor
@Suite("FakeFireCircleTransport")
struct FakeFireCircleTransportTests {
    private func makeCook(peerID: String = "peer1") -> FireCircleCook {
        FireCircleCook(
            peerID: peerID,
            cookName: "Chef",
            recipeTitle: "Ribs",
            stepText: "Smoke",
            remainingSeconds: 60,
            endDate: nil,
            isPaused: true,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("start sets isRunning")
    func startSetsIsRunning() {
        let transport = FakeFireCircleTransport()
        #expect(transport.isRunning == false)
        transport.start(localPeerID: "me", displayName: "Me") { _ in }
        #expect(transport.isRunning)
    }

    @Test("broadcast appends to broadcasts")
    func broadcastAppends() {
        let transport = FakeFireCircleTransport()
        let cook = makeCook()
        transport.broadcast(cook)
        #expect(transport.broadcasts == [cook])
    }

    @Test("simulate calls the onEvent closure")
    func simulateCallsOnEvent() {
        let transport = FakeFireCircleTransport()
        var events: [FireCircleEvent] = []
        transport.start(localPeerID: "me", displayName: "Me") { events.append($0) }
        let cook = makeCook()
        transport.simulate(.received(cook))
        transport.simulate(.peerLeft(peerID: "peer1"))
        #expect(events == [.received(cook), .peerLeft(peerID: "peer1")])
    }

    @Test("simulate is a no-op after stop")
    func simulateNoOpAfterStop() {
        let transport = FakeFireCircleTransport()
        var events: [FireCircleEvent] = []
        transport.start(localPeerID: "me", displayName: "Me") { events.append($0) }
        transport.stop()
        transport.simulate(.peerLeft(peerID: "peer1"))
        #expect(transport.isRunning == false)
        #expect(events.isEmpty)
    }
}

import DODCookActivity
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("FireCircleSession")
struct FireCircleSessionTests {
    private let sentAt = Date(timeIntervalSince1970: 1_000)

    private func makeSession(_ fake: FakeFireCircleTransport) -> FireCircleSession {
        FireCircleSession(
            transport: fake,
            localPeerID: "me",
            cookName: "Ned",
            now: { Date(timeIntervalSince1970: 1_000) }
        )
    }

    private func remoteCook(sentAt: Date) -> FireCircleCook {
        FireCircleCook(
            peerID: "peer-1",
            cookName: "Sam",
            recipeTitle: "Chili",
            stepText: "Simmer",
            remainingSeconds: 60,
            endDate: nil,
            isPaused: true,
            isCompleted: false,
            sentAt: sentAt
        )
    }

    @Test func publishBeforeJoinSendsNothing() {
        let fake = FakeFireCircleTransport()
        let session = makeSession(fake)
        session.publish(
            attributes: CookActivityAttributes(recipeTitle: "Chili", recipeID: 1, totalSeconds: 60),
            state: .init(remainingSeconds: 30, stepText: "Stir", isPaused: false)
        )
        #expect(fake.broadcasts.isEmpty)
    }

    @Test func publishAfterJoinBroadcastsMatchingFields() {
        let fake = FakeFireCircleTransport()
        let session = makeSession(fake)
        session.join()
        let end = Date(timeIntervalSince1970: 2_000)
        session.publish(
            attributes: CookActivityAttributes(recipeTitle: "Chili", recipeID: 1, totalSeconds: 60),
            state: .init(remainingSeconds: 30, stepText: "Stir", isPaused: false, endDate: end, isCompleted: false)
        )
        #expect(fake.broadcasts.count == 1)
        let sent = fake.broadcasts.first
        #expect(sent?.peerID == "me")
        #expect(sent?.cookName == "Ned")
        #expect(sent?.recipeTitle == "Chili")
        #expect(sent?.stepText == "Stir")
        #expect(sent?.remainingSeconds == 30)
        #expect(sent?.endDate == end)
        #expect(sent?.isPaused == false)
        #expect(sent?.isCompleted == false)
        #expect(sent?.sentAt == sentAt)
    }

    @Test func receivedCookLandsOnBoard() {
        let fake = FakeFireCircleTransport()
        let session = makeSession(fake)
        session.join()
        let cook = remoteCook(sentAt: sentAt)
        fake.simulate(.received(cook))
        #expect(session.board.cooks.count == 1)
        #expect(session.board.cooks["peer-1"]?.stepText == "Simmer")
    }

    @Test func peerLeftRemovesFromBoard() {
        let fake = FakeFireCircleTransport()
        let session = makeSession(fake)
        session.join()
        let cook = remoteCook(sentAt: sentAt)
        fake.simulate(.received(cook))
        #expect(session.board.cooks.count == 1)
        fake.simulate(.peerLeft(peerID: "peer-1"))
        #expect(session.board.cooks.isEmpty)
    }

    @Test func joinTwiceIsIdempotent() {
        let fake = FakeFireCircleTransport()
        let session = makeSession(fake)
        session.join()
        session.join()
        #expect(session.isOn)
        #expect(fake.isRunning)
    }

    @Test func leaveStopsTransportAndClearsBoard() {
        let fake = FakeFireCircleTransport()
        let session = makeSession(fake)
        session.join()
        let cook = remoteCook(sentAt: sentAt)
        fake.simulate(.received(cook))
        #expect(session.board.cooks.count == 1)
        session.leave()
        #expect(!session.isOn)
        #expect(!fake.isRunning)
        #expect(session.board.cooks.isEmpty)
    }
}

import Foundation
import Testing

@testable import DODSupport

@Suite("FireCircleBoard")
struct FireCircleBoardTests {

    @Test("Newer packet replaces older one")
    func newerPacketReplacesOlder() {
        var board = FireCircleBoard()

        let cook1 = FireCircleCook(
            peerID: "peer1",
            cookName: "Chef 1",
            recipeTitle: "Recipe 1",
            stepText: "Step 1",
            remainingSeconds: 300,
            endDate: Date(timeIntervalSince1970: 1_700_000_600),
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )

        let cook2 = FireCircleCook(
            peerID: "peer1",
            cookName: "Chef 1",
            recipeTitle: "Recipe 1",
            stepText: "Step 1",
            remainingSeconds: 200,
            endDate: Date(timeIntervalSince1970: 1_700_000_500),
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_700)
        )

        board.apply(cook1)
        board.apply(cook2)

        #expect(board.cooks["peer1"] == cook2)
    }

    @Test("Older packet is ignored")
    func olderPacketIsIgnored() {
        var board = FireCircleBoard()

        let cook1 = FireCircleCook(
            peerID: "peer1",
            cookName: "Chef 1",
            recipeTitle: "Recipe 1",
            stepText: "Step 1",
            remainingSeconds: 300,
            endDate: Date(timeIntervalSince1970: 1_700_000_600),
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )

        let cook2 = FireCircleCook(
            peerID: "peer1",
            cookName: "Chef 1",
            recipeTitle: "Recipe 1",
            stepText: "Step 1",
            remainingSeconds: 200,
            endDate: Date(timeIntervalSince1970: 1_700_000_500),
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_700)
        )

        board.apply(cook2)
        board.apply(cook1)

        #expect(board.cooks["peer1"] == cook2)
    }

    @Test("Remove works")
    func removeWorks() {
        var board = FireCircleBoard()

        let cook1 = FireCircleCook(
            peerID: "peer1",
            cookName: "Chef 1",
            recipeTitle: "Recipe 1",
            stepText: "Step 1",
            remainingSeconds: 300,
            endDate: Date(timeIntervalSince1970: 1_700_000_600),
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )

        board.apply(cook1)
        board.remove(peerID: "peer1")

        #expect(board.cooks["peer1"] == nil)
    }

    @Test("Sorted ordering - completed cooks first")
    func sortedOrderingCompletedCooksFirst() {
        var board = FireCircleBoard()

        let now = Date(timeIntervalSince1970: 1_700_000_600)

        let cook1 = makeCook1()
        let cook2 = makeCook2()
        let cook3 = makeCook3()
        let cook4 = makeCook4()

        board.apply(cook1)
        board.apply(cook2)
        board.apply(cook3)
        board.apply(cook4)

        let sorted = board.sorted(now: now)

        // Completed cooks come first
        #expect(sorted[0].isCompleted == true)
        #expect(sorted[1].isCompleted == false)  // cook1
        #expect(sorted[2].isCompleted == false)  // cook2
        #expect(sorted[3].isCompleted == false)  // cook3 (paused after running)
    }

    private func makeCook1() -> FireCircleCook {
        FireCircleCook(
            peerID: "peer1",
            cookName: "Chef 1",
            recipeTitle: "Recipe 1",
            stepText: "Step 1",
            remainingSeconds: 300,
            endDate: Date(timeIntervalSince1970: 1_700_000_900),  // 300 seconds in future
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
    }

    private func makeCook2() -> FireCircleCook {
        FireCircleCook(
            peerID: "peer2",
            cookName: "Chef 2",
            recipeTitle: "Recipe 2",
            stepText: "Step 2",
            remainingSeconds: 600,
            endDate: Date(timeIntervalSince1970: 1_700_001_200),  // 600 seconds in future
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
    }

    private func makeCook3() -> FireCircleCook {
        FireCircleCook(
            peerID: "peer3",
            cookName: "Chef 3",
            recipeTitle: "Recipe 3",
            stepText: "Step 3",
            remainingSeconds: 100,
            endDate: nil,
            isPaused: true,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
    }

    private func makeCook4() -> FireCircleCook {
        FireCircleCook(
            peerID: "peer4",
            cookName: "Chef 4",
            recipeTitle: "Recipe 4",
            stepText: "Step 4",
            remainingSeconds: 0,
            endDate: nil,
            isPaused: false,
            isCompleted: true,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
    }

    @Test("Remaining time calculation")
    func remainingTimeCalculation() {
        let now = Date(timeIntervalSince1970: 1_700_000_600)

        // Running cook
        let cook1 = FireCircleCook(
            peerID: "peer1",
            cookName: "Chef 1",
            recipeTitle: "Recipe 1",
            stepText: "Step 1",
            remainingSeconds: 300,
            endDate: Date(timeIntervalSince1970: 1_700_000_900),  // 300 seconds in future
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )

        // Paused cook
        let cook2 = FireCircleCook(
            peerID: "peer2",
            cookName: "Chef 2",
            recipeTitle: "Recipe 2",
            stepText: "Step 2",
            remainingSeconds: 300,
            endDate: nil,
            isPaused: true,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )

        // Overdue cook
        let cook3 = FireCircleCook(
            peerID: "peer3",
            cookName: "Chef 3",
            recipeTitle: "Recipe 3",
            stepText: "Step 3",
            remainingSeconds: 100,
            endDate: Date(timeIntervalSince1970: 1_700_000_500),  // Already expired
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_500)
        )

        #expect(cook1.remaining(now: now) == 300)
        #expect(cook2.remaining(now: now) == 300)
        #expect(cook3.remaining(now: now) == 0)
    }
}

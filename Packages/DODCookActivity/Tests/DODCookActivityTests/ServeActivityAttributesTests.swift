import Foundation
import Testing

@testable import DODCookActivity

@Suite("ServeActivityAttributes")
struct ServeActivityAttributesTests {

    private func makeDish(id: Int, cookStart: TimeInterval) -> ServeActivityAttributes.Dish {
        ServeActivityAttributes.Dish(
            id: id,
            title: "Dish \(id)",
            cookStart: Date(timeIntervalSince1970: cookStart),
            serveAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    @Test("ContentState round-trips through JSON and stays equal")
    func contentStateRoundTrips() throws {
        let state = ServeActivityAttributes.ContentState(
            dishes: [makeDish(id: 1, cookStart: 100), makeDish(id: 2, cookStart: 200)],
            serveAt: Date(timeIntervalSince1970: 1_000),
            isCompleted: true
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ServeActivityAttributes.ContentState.self, from: data)
        #expect(decoded == state)
    }

    @Test("upcoming and cooking split dishes by cookStart")
    func upcomingAndCookingSplit() {
        let state = ServeActivityAttributes.ContentState(
            dishes: [makeDish(id: 1, cookStart: 100), makeDish(id: 2, cookStart: 200)],
            serveAt: Date(timeIntervalSince1970: 1_000)
        )
        let now = Date(timeIntervalSince1970: 150)
        let upcoming = state.upcoming(at: now)
        let cooking = state.cooking(at: now)
        #expect(upcoming.count == 1)
        #expect(upcoming.first?.id == 2)
        #expect(cooking.count == 1)
        #expect(cooking.first?.id == 1)
    }
}

import DODCookActivity
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("ServeActivityStateBuilder")
struct ServeActivityStateBuilderTests {

    private let serveAt = Date(timeIntervalSince1970: 100_000)

    private var plan: [ServingScheduleEntry] {
        let ribs = ServingDish(id: 1, title: "Ribs", prepSeconds: 900, cookSeconds: 3600)
        let corn = ServingDish(id: 2, title: "Corn", prepSeconds: 300, cookSeconds: 1200)
        return ServingPlanner.plan(dishes: [corn, ribs], serveAt: serveAt)
    }

    @Test func stateMapsPlanInOrder() {
        let plan = plan
        let state = ServeActivityStateBuilder.state(from: plan, serveAt: serveAt)

        #expect(state.dishes.count == 2)
        #expect(state.dishes.map(\.id) == plan.map(\.dishID))
        #expect(state.dishes.map(\.cookStart) == plan.map(\.cookStart))
        #expect(state.serveAt == serveAt)
        #expect(state.isCompleted == false)
    }

    @Test func completedFlipsFlagAndKeepsDishes() {
        let state = ServeActivityStateBuilder.state(from: plan, serveAt: serveAt)
        let done = ServeActivityStateBuilder.completed(state)

        #expect(done.isCompleted)
        #expect(done.dishes == state.dishes)
        #expect(done.serveAt == state.serveAt)
    }

    @Test func attributesUseDefaultTitle() {
        #expect(ServeActivityStateBuilder.attributes().title == "Dinner is served")
    }
}

import Foundation
import Testing

@testable import DODDomain

@Suite("ServingPlanner")
struct ServingPlannerTests {

    private let serveAt = Date(timeIntervalSince1970: 100_000)

    @Test func staggersDishesBackwardFromServeTime() throws {
        let ribs = ServingDish(id: 1, title: "Ribs", prepSeconds: 15 * 60, cookSeconds: 60 * 60)
        let corn = ServingDish(id: 2, title: "Corn", prepSeconds: 5 * 60, cookSeconds: 20 * 60)
        // Pass the short dish first to prove the planner sorts.
        let plan = ServingPlanner.plan(dishes: [corn, ribs], serveAt: serveAt)

        #expect(plan.count == 2)
        #expect(plan.allSatisfy { $0.serveAt == serveAt })
        let first = try #require(plan.first)
        #expect(first.dishID == 1)
        #expect(first.cookStart == serveAt.addingTimeInterval(-3600))
        #expect(first.prepStart == serveAt.addingTimeInterval(-4500))
        #expect(plan.map(\.dishID) == [1, 2])
        #expect(ServingPlanner.earliestStart(of: plan) == first.prepStart)
    }

    @Test func emptyDishesYieldsEmptyPlanAndNilEarliestStart() {
        let plan = ServingPlanner.plan(dishes: [], serveAt: serveAt)
        #expect(plan.isEmpty)
        #expect(ServingPlanner.earliestStart(of: plan) == nil)
    }

    @Test func zeroTimesCollapseToServeTime() throws {
        let dish = ServingDish(id: 3, title: "Salad", prepSeconds: 0, cookSeconds: 0)
        let entry = try #require(ServingPlanner.plan(dishes: [dish], serveAt: serveAt).first)
        #expect(entry.prepStart == serveAt)
        #expect(entry.cookStart == serveAt)
        #expect(entry.serveAt == serveAt)
    }

    @Test func negativeSecondsClampToZero() {
        let dish = ServingDish(id: 4, title: "Odd", prepSeconds: -5, cookSeconds: -9)
        #expect(dish.prepSeconds == 0)
        #expect(dish.cookSeconds == 0)
    }

    @Test func tiesBreakOnDishID() {
        let later = ServingDish(id: 9, title: "B", prepSeconds: 60, cookSeconds: 60)
        let earlier = ServingDish(id: 5, title: "A", prepSeconds: 60, cookSeconds: 60)
        let plan = ServingPlanner.plan(dishes: [later, earlier], serveAt: serveAt)
        #expect(plan.map(\.dishID) == [5, 9])
    }
}

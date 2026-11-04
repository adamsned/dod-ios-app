import SwiftTesting
import SwiftUI
import XCTest

@testable import DODCookActivity

@available(iOS 16.1, *)
struct ServeActivityViewsTests {

    @Test
    func serveActivityRowsWithNow150() {
        // Test with now = 150, a dish with cookStart = 200 yields a row with .upcoming and target == cookStart
        let dish1 = ServeActivityAttributes.Dish(
            id: 1,
            title: "Dish 1",
            cookStart: Date(timeIntervalSince1970: 200),
            serveAt: Date(timeIntervalSince1970: 300)
        )
        let dish2 = ServeActivityAttributes.Dish(
            id: 2,
            title: "Dish 2",
            cookStart: Date(timeIntervalSince1970: 100),
            serveAt: Date(timeIntervalSince1970: 250)
        )

        let state = ServeActivityAttributes.ContentState(
            dishes: [dish1, dish2],
            serveAt: Date(timeIntervalSince1970: 350)
        )

        let now = Date(timeIntervalSince1970: 150)
        let rows = serveActivityRows(state: state, now: now)

        // Check that we have two rows
        #expect(rows.count == 2)

        // First dish should be upcoming with cookStart as target
        #expect(rows[0].id == 1)
        #expect(rows[0].title == "Dish 1")
        #expect(rows[0].phase == .upcoming)
        #expect(rows[0].target == dish1.cookStart)

        // Second dish should be cooking with serveAt as target
        #expect(rows[1].id == 2)
        #expect(rows[1].title == "Dish 2")
        #expect(rows[1].phase == .cooking)
        #expect(rows[1].target == dish2.serveAt)
    }

    @Test
    func serveActivityRowsOrderMatchesDishes() {
        // Test that the row order matches the state.dishes order
        let dish1 = ServeActivityAttributes.Dish(
            id: 1,
            title: "First Dish",
            cookStart: Date(timeIntervalSince1970: 200),
            serveAt: Date(timeIntervalSince1970: 300)
        )
        let dish2 = ServeActivityAttributes.Dish(
            id: 2,
            title: "Second Dish",
            cookStart: Date(timeIntervalSince1970: 100),
            serveAt: Date(timeIntervalSince1970: 250)
        )

        let state = ServeActivityAttributes.ContentState(
            dishes: [dish1, dish2],
            serveAt: Date(timeIntervalSince1970: 350)
        )

        let now = Date(timeIntervalSince1970: 150)
        let rows = serveActivityRows(state: state, now: now)

        // Check that the order is preserved
        #expect(rows[0].title == "First Dish")
        #expect(rows[1].title == "Second Dish")
    }
}

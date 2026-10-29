import Foundation
import Testing

@testable import DODSupport

@Suite("GuestMenuSnapshot")
struct GuestMenuSnapshotTests {

    @Test("Status is upNext when now is before start time")
    func statusUpNext() {
        // Using a dish with cookMinutes: 60 and serveAt = epoch 1_700_000_000
        let serveAt = Date(timeIntervalSince1970: 1_700_000_000)

        let plan = CookoutPlan(
            name: "Test Plan",
            guestCount: 10,
            serveAt: serveAt,
            dishes: [
                .init(recipeID: 1, title: "Test Dish", sourceServings: 4, cookMinutes: 60)
            ]
        )

        let now = serveAt.addingTimeInterval(-7200)  // exactly at start time (2 hours before)

        let snapshot = GuestMenuSnapshot.make(from: plan, now: now)
        #expect(snapshot.items[0].status == .upNext)
    }

    @Test("Status is cooking when now is between start and serve time")
    func statusCooking() {
        // Using a dish with cookMinutes: 60 and serveAt = epoch 1_700_000_000
        let serveAt = Date(timeIntervalSince1970: 1_700_000_000)

        let plan = CookoutPlan(
            name: "Test Plan",
            guestCount: 10,
            serveAt: serveAt,
            dishes: [
                .init(recipeID: 1, title: "Test Dish", sourceServings: 4, cookMinutes: 60)
            ]
        )

        let now = serveAt.addingTimeInterval(-1800)  // exactly at start time (30 minutes before)

        let snapshot = GuestMenuSnapshot.make(from: plan, now: now)
        #expect(snapshot.items[0].status == .cooking)
    }

    @Test("Status is ready when now is after serve time")
    func statusReady() {
        // Using a dish with cookMinutes: 60 and serveAt = epoch 1_700_000_000
        let serveAt = Date(timeIntervalSince1970: 1_700_000_000)

        let plan = CookoutPlan(
            name: "Test Plan",
            guestCount: 10,
            serveAt: serveAt,
            dishes: [
                .init(recipeID: 1, title: "Test Dish", sourceServings: 4, cookMinutes: 60)
            ]
        )

        let now = serveAt  // exactly at serve time

        let snapshot = GuestMenuSnapshot.make(from: plan, now: now)
        #expect(snapshot.items[0].status == .ready)
    }

    @Test("Items are ordered according to scheduler")
    func itemOrdering() {
        // Using two dishes with different start times
        let serveAt = Date(timeIntervalSince1970: 1_700_000_000)

        let plan = CookoutPlan(
            name: "Test Plan",
            guestCount: 10,
            serveAt: serveAt,
            dishes: [
                .init(recipeID: 1, title: "First Dish", sourceServings: 4, cookMinutes: 60),
                .init(recipeID: 2, title: "Second Dish", sourceServings: 4, cookMinutes: 30),
            ]
        )

        let now = serveAt.addingTimeInterval(-3600)  // 1 hour before serveAt

        let snapshot = GuestMenuSnapshot.make(from: plan, now: now)

        // Check that items are ordered as per the scheduler (first dish starts earlier)
        #expect(snapshot.items[0].recipeID == 1)
        #expect(snapshot.items[1].recipeID == 2)
    }
}

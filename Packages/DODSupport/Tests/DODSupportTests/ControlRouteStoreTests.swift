import Foundation
import Testing

@testable import DODSupport

/// DUT-480 / CL-301 — behavioural tests for the Control Center pending-route
/// flag. Uses the `init(defaults:)` seam with a throwaway suite so nothing
/// touches the real App Group or `.standard`.
@Suite("ControlRouteStore") struct ControlRouteStoreTests {

    /// A fresh, isolated `UserDefaults` suite per test. Removing the suite up
    /// front guarantees a clean slate even if a prior run crashed mid-test.
    private func makeStore() throws -> ControlRouteStore {
        let suite = "dod.test.control.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return ControlRouteStore(defaults: defaults)
    }

    @Test func setThenTakeReturnsRouteAndClears() throws {
        let store = try makeStore()
        store.setPending(.shoppingList)
        #expect(store.takePending() == .shoppingList)
        // Take-once: the flag is consumed, so a second take sees nothing.
        #expect(store.takePending() == nil)
    }

    @Test func takeOnEmptyReturnsNil() throws {
        let store = try makeStore()
        #expect(store.takePending() == nil)
    }

    /// DUT-560 — every configurable-control tool round-trips through the flag,
    /// and each raw token stays stable across binary versions.
    @Test(arguments: [
        (ControlRouteStore.Route.shoppingList, "shopping-list"),
        (.heatCoach, "heat-coach"),
        (.cookingJournal, "journal"),
        (.firstCookout, "first-cookout"),
        (.cookMode, "cook-mode"),
        (.buyBuzzyWaxx, "buzzywaxx"),
    ])
    func routeRoundTrips(route: ControlRouteStore.Route, rawValue: String) throws {
        #expect(route.rawValue == rawValue)
        let store = try makeStore()
        store.setPending(route)
        #expect(store.takePending() == route)
        #expect(store.takePending() == nil)
    }
}

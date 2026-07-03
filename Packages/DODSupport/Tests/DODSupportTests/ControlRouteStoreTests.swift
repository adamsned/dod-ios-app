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
}

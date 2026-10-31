import Foundation
import Testing

@testable import DODSupport

@Suite("CampTripStore (DUT-1000)")
struct CampTripStoreTests {
    private func makeStore() throws -> ((CampTripStore, UserDefaults), String) {
        let suite = "dut1000.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return ((CampTripStore(defaults: defaults), defaults), suite)
    }

    private func sampleSnapshot() -> CampTripStore.Snapshot {
        let meal = CampMeal(
            day: 0,
            recipeTitle: "Cobbler",
            ovenTempF: 350,
            task: .bake,
            ingredients: ["2 cups peaches"]
        )
        let trip = CampTrip(name: "Lake", nights: 2, meals: [meal])
        var ledger = CampFuelLedger(packedBriquettes: 30)
        ledger.recordUsed(12, for: meal.id)
        return CampTripStore.Snapshot(trip: trip, ledger: ledger)
    }

    @Test func loadIsNilOnEmptyStore() throws {
        let ((store, defaults), suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.load() == nil)
    }

    @Test func saveThenLoadRoundTripsTripAndLedger() throws {
        let ((store, defaults), suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let snapshot = sampleSnapshot()
        store.save(snapshot)
        let loaded = try #require(store.load())
        #expect(loaded == snapshot)
        #expect(loaded.ledger.totalUsed == 12)
        #expect(loaded.ledger.remaining == 18)
    }

    @Test func clearReturnsStoreToNil() throws {
        let ((store, defaults), suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save(sampleSnapshot())
        store.clear()
        #expect(store.load() == nil)
    }

    @Test func corruptDataLoadsAsNil() throws {
        let ((store, defaults), suite) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: CampTripStore.key)
        #expect(store.load() == nil)
    }
}

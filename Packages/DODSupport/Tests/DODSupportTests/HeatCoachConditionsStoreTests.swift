import Foundation
import Testing

@testable import DODSupport

@Suite struct HeatCoachConditionsStoreTests {
    @Test func loadEmpty() {
        let defaults = UserDefaults(suiteName: UUID().uuidString) ?? UserDefaults.standard
        let store = HeatCoachConditionsStore(defaults: defaults)
        #expect(store.load() == nil)
    }

    @Test func saveLoad() {
        let defaults = UserDefaults(suiteName: UUID().uuidString) ?? UserDefaults.standard
        let store = HeatCoachConditionsStore(defaults: defaults)

        let conditions = HeatCoachConditions(
            elevationFeet: 1000,
            ambient: .mild,
            windy: true,
            fetchedAt: Date()
        )

        store.save(conditions)
        let loaded = store.load()
        #expect(loaded == conditions)
    }

    @Test func clear() {
        let defaults = UserDefaults(suiteName: UUID().uuidString) ?? UserDefaults.standard
        let store = HeatCoachConditionsStore(defaults: defaults)

        let conditions = HeatCoachConditions(
            elevationFeet: 1000,
            ambient: .mild,
            windy: true,
            fetchedAt: Date()
        )

        store.save(conditions)
        store.clear()
        #expect(store.load() == nil)
    }

    @Test func corruptData() {
        let defaults = UserDefaults(suiteName: UUID().uuidString) ?? UserDefaults.standard
        defaults.set(Data([1, 2, 3]), forKey: HeatCoachConditionsStore.key)
        let store = HeatCoachConditionsStore(defaults: defaults)
        #expect(store.load() == nil)
    }
}

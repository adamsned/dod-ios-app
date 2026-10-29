import Foundation
import Testing

@testable import DODSupport

@Suite("CookoutPlanStore") struct CookoutPlanStoreTests {

    private static func freshDefaults() throws -> UserDefaults {
        let name = "dod.cookout.store.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func samplePlan() -> CookoutPlan {
        CookoutPlan(
            name: "Family Cookout",
            guestCount: 12,
            // Whole seconds, so the .secondsSince1970 round trip is exact.
            serveAt: Date(timeIntervalSince1970: 1_800_000_000),
            dishes: [
                .init(recipeID: 1, title: "Peach Cobbler", sourceServings: 8, isBaking: true, cookMinutes: 45),
                .init(recipeID: 2, title: "Chili", sourceServings: 6, cookMinutes: 90),
            ]
        )
    }

    @Test func loadOnFreshDefaultsIsNil() throws {
        let store = CookoutPlanStore(defaults: try Self.freshDefaults())
        #expect(store.load() == nil)
    }

    @Test func saveThenLoadRoundTrips() throws {
        let store = CookoutPlanStore(defaults: try Self.freshDefaults())
        let plan = Self.samplePlan()
        store.save(plan)
        #expect(store.load() == plan)
    }

    @Test func clearRemovesSavedPlan() throws {
        let store = CookoutPlanStore(defaults: try Self.freshDefaults())
        store.save(Self.samplePlan())
        store.clear()
        #expect(store.load() == nil)
    }

    @Test func corruptDataLoadsAsNil() throws {
        let defaults = try Self.freshDefaults()
        defaults.set(Data([1, 2, 3]), forKey: CookoutPlanStore.key)
        #expect(CookoutPlanStore(defaults: defaults).load() == nil)
    }
}

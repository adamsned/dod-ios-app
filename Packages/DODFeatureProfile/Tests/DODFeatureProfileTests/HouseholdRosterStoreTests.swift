import Foundation
import Testing

@testable import DODFeatureProfile

@Suite("HouseholdRosterStore (DUT-1775)")
struct HouseholdRosterStoreTests {
    @Test func inMemoryRoundTrip() async {
        let store = InMemoryHouseholdRosterStore()
        let members = [
            HouseholdMember(name: "Sam", ageBand: .kid, flags: [.nuts]),
            HouseholdMember(name: "Alex", ageBand: .teenOrAdult, flags: [.dairy, .gluten]),
        ]
        await store.save(members)
        let loaded = await store.load()
        #expect(loaded == members)
    }

    @Test func userDefaultsRoundTrip() async throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let store = UserDefaultsHouseholdRosterStore(defaults: defaults)
        let members = [
            HouseholdMember(name: "Sam", ageBand: .kid, flags: [.nuts]),
            HouseholdMember(name: "Alex", ageBand: .teenOrAdult, flags: [.dairy]),
        ]
        await store.save(members)
        let loaded = await store.load()
        #expect(loaded == members)
    }

    @Test func corruptDataLoadsEmpty() async throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        defaults.set(Data([0x00]), forKey: UserDefaultsHouseholdRosterStore.key)
        let store = UserDefaultsHouseholdRosterStore(defaults: defaults)
        let loaded = await store.load()
        #expect(loaded.isEmpty)
    }
}

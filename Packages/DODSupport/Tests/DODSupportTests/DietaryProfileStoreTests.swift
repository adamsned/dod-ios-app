import Foundation
import Testing

@testable import DODSupport

@Suite("DietaryProfileStore (DUT-1674)")
struct DietaryProfileStoreTests {
    private func makeDefaults() throws -> UserDefaults {
        let suite = "dut1674.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("empty defaults load the empty profile")
    func emptyDefaultsLoadsDefaultProfile() throws {
        let store = DietaryProfileStore(defaults: try makeDefaults())
        #expect(store.load() == DietaryProfile())
    }

    @Test("saved profile round-trips through load")
    func saveThenLoadRoundTrips() throws {
        let store = DietaryProfileStore(defaults: try makeDefaults())
        let profile = DietaryProfile(
            patterns: [.vegan],
            allergens: [.nuts],
            onlyShowFitting: true
        )
        store.save(profile)
        #expect(store.load() == profile)
    }

    @Test("corrupt data loads the empty profile")
    func corruptDataLoadsDefaultProfile() throws {
        let defaults = try makeDefaults()
        defaults.set(Data("nope".utf8), forKey: DietaryProfileStore.defaultsKey)
        let store = DietaryProfileStore(defaults: defaults)
        #expect(store.load() == DietaryProfile())
    }
}

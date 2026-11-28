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
}

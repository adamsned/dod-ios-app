import Foundation
import Testing

@testable import DODSupport

@Suite("CookIntakeProfileStore (DUT-1032)")
struct CookIntakeProfileStoreTests {
    @Test func emptyStoreHasNoProfileAndIsNotCompleted() throws {
        let suite = "CookIntakeProfileStoreTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookIntakeProfileStore(defaults: defaults)
        #expect(store.profile() == nil)
        #expect(store.isCompleted == false)
    }

    @Test func saveThenReadRoundTrips() throws {
        let suite = "CookIntakeProfileStoreTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookIntakeProfileStore(defaults: defaults)
        let profile = CookIntakeProfile(
            fearLevel: .nervous,
            occasion: .campout,
            householdSize: 4,
            biggestWorry: "sticking"
        )
        store.save(profile)
        #expect(store.profile() == profile)
        #expect(store.isCompleted == true)
    }

    @Test func markSkippedCompletesWithoutProfile() throws {
        let suite = "CookIntakeProfileStoreTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookIntakeProfileStore(defaults: defaults)
        store.markSkipped()
        #expect(store.profile() == nil)
        #expect(store.isCompleted == true)
    }
}

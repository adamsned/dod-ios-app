import Foundation
import Testing

@testable import DODSupport

@Suite("OneBiteStore (DUT-996)")
struct OneBiteStoreTests {

    private func entry(_ seconds: TimeInterval) -> DinerReactionEntry {
        DinerReactionEntry(
            dinerKey: "jake",
            dinerName: "Jake",
            recipeID: 1,
            recipeTitle: "Chili",
            reaction: .tried,
            loggedAt: Date(timeIntervalSince1970: seconds)
        )
    }

    @Test func emptyByDefault() throws {
        let name = "OneBiteStoreTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: name))
        defer { userDefaults.removePersistentDomain(forName: name) }
        #expect(OneBiteStore(defaults: userDefaults).entries().isEmpty)
    }

    @Test func addPersistsNewestFirst() throws {
        let name = "OneBiteStoreTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: name))
        defer { userDefaults.removePersistentDomain(forName: name) }
        let store = OneBiteStore(defaults: userDefaults)
        store.add(entry(1))
        store.add(entry(2))
        #expect(store.entries().first?.loggedAt == Date(timeIntervalSince1970: 2))
        #expect(OneBiteStore(defaults: userDefaults).entries().count == 2)
    }

    @Test func capsAtMaxEntries() throws {
        let name = "OneBiteStoreTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: name))
        defer { userDefaults.removePersistentDomain(forName: name) }
        let store = OneBiteStore(defaults: userDefaults)
        for index in 0..<(OneBiteStore.maxEntries + 5) { store.add(entry(TimeInterval(index))) }
        #expect(store.entries().count == OneBiteStore.maxEntries)
    }
}

import Foundation
import Testing

@testable import DODFeatureSearch

@Suite("RecentSearches (US-12 / AC-12.4)") struct RecentSearchesTests {

    @Test func recordPlacesAtFront() {
        let recents = scratch()
        recents.record("alpha")
        recents.record("beta")
        #expect(recents.recent() == ["beta", "alpha"])
    }

    @Test func repeatedRecordMovesToFront() {
        let recents = scratch()
        recents.record("alpha")
        recents.record("beta")
        recents.record("alpha")
        #expect(recents.recent() == ["alpha", "beta"])
    }

    @Test func caseInsensitiveDedupe() {
        let recents = scratch()
        recents.record("Pasta")
        recents.record("pasta")
        #expect(recents.recent() == ["pasta"])
    }

    @Test func trimmedToMaxEntries() {
        let recents = scratch()
        for index in 0..<(RecentSearches.maxEntries + 5) {
            recents.record("q\(index)")
        }
        #expect(recents.recent().count == RecentSearches.maxEntries)
        #expect(recents.recent().first == "q\(RecentSearches.maxEntries + 4)")
    }

    @Test func whitespaceQueriesAreIgnored() {
        let recents = scratch()
        recents.record("   ")
        recents.record("")
        #expect(recents.recent().isEmpty)
    }

    @Test func clearRemovesAll() {
        let recents = scratch()
        recents.record("alpha")
        recents.clear()
        #expect(recents.recent().isEmpty)
    }

    private func scratch() -> RecentSearches {
        let suiteName = "dod.recentSearchesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}

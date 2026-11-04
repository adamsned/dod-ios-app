import Foundation
import Testing

@testable import DODSupport

/// DUT-157 — persisted engagement counters for the review prompt.
@Suite("ReviewPromptStore (DUT-157)")
struct ReviewPromptStoreTests {

    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "ReviewPromptStoreTests-\(UUID().uuidString)"))
    }

    @Test func freshStoreIsEmpty() throws {
        let store = ReviewPromptStore(defaults: try makeDefaults())
        #expect(store.sessionCount == 0)
        #expect(store.recipeViewCount == 0)
        #expect(store.completedCookCount == 0)
        #expect(store.lastPromptDate == nil)
        #expect(store.declined == false)
    }

    @Test func recordSessionTwiceGivesTwo() throws {
        let store = ReviewPromptStore(defaults: try makeDefaults())
        store.recordSession()
        store.recordSession()
        #expect(store.sessionCount == 2)
    }

    @Test func countersIncrementIndependently() throws {
        let store = ReviewPromptStore(defaults: try makeDefaults())
        store.recordRecipeView()
        #expect(store.recipeViewCount == 1)
        #expect(store.sessionCount == 0)
        #expect(store.completedCookCount == 0)
        store.recordCompletedCook()
        #expect(store.completedCookCount == 1)
        #expect(store.recipeViewCount == 1)
        #expect(store.sessionCount == 0)
    }

    @Test func persistsAcrossInstances() throws {
        let defaults = try makeDefaults()
        let first = ReviewPromptStore(defaults: defaults)
        first.recordSession()
        first.recordRecipeView()
        first.recordCompletedCook()
        let date = Date(timeIntervalSince1970: 1_000_000)
        first.lastPromptDate = date
        first.declined = true
        let second = ReviewPromptStore(defaults: defaults)
        #expect(second.sessionCount == 1)
        #expect(second.recipeViewCount == 1)
        #expect(second.completedCookCount == 1)
        #expect(second.lastPromptDate == date)
        #expect(second.declined == true)
    }
}

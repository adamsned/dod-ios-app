import Testing

@testable import DODAnalytics

@Suite("AnalyticsEvent payload contract") struct AnalyticsEventTests {

    @Test func appOpenHasNoPayload() {
        let event = AnalyticsEvent.appOpen
        #expect(event.name == "app_open")
        #expect(event.payload.isEmpty)
    }

    @Test func screenViewCarriesScreenName() {
        let event = AnalyticsEvent.screenView(name: "feed")
        #expect(event.name == "screen_view")
        #expect(event.payload == ["screen": "feed"])
    }

    @Test func recipeViewCarriesRecipeID() {
        let event = AnalyticsEvent.recipeView(recipeID: 42)
        #expect(event.payload == ["recipe_id": "42"])
    }

    @Test func recipeSearchedCarriesHashOnly() {
        let event = AnalyticsEvent.recipeSearched(queryHash: "abc123")
        #expect(event.payload == ["query_hash": "abc123"])
        // Constitution §9, spec AC-3.6: raw user input must never appear in payload.
        for value in event.payload.values {
            #expect(!value.contains(" "), "Payload should be a hash, not raw search text")
        }
    }

    @Test func allEventNamesAreUnique() {
        let allNames: [String] = [
            AnalyticsEvent.appOpen.name,
            AnalyticsEvent.screenView(name: "x").name,
            AnalyticsEvent.recipeView(recipeID: 1).name,
            AnalyticsEvent.recipeSaved(recipeID: 1).name,
            AnalyticsEvent.recipeUnsaved(recipeID: 1).name,
            AnalyticsEvent.recipeSearched(queryHash: "h").name,
            AnalyticsEvent.recipeShared(recipeID: 1).name,
            AnalyticsEvent.offlineRead(recipeID: 1).name,
        ]
        #expect(Set(allNames).count == allNames.count)
    }
}

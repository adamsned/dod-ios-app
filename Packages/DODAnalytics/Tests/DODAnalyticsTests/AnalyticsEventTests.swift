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

    @Test func cookModeStartedCarriesOnlyRecipeID() {
        // Spec AC-7.7 + constitution §9: payload is exactly { recipe_id } —
        // no free-text, no step index, nothing the user typed.
        let event = AnalyticsEvent.cookModeStarted(recipeID: 7)
        #expect(event.name == "cook_mode_started")
        #expect(event.payload == ["recipe_id": "7"])
        #expect(event.payload.keys.count == 1)
    }

    @Test func recipeRatedCarriesRecipeIDAndStars() {
        // Spec AC-13.5 + constitution §9 (CL-21 amendment): payload is
        // exactly { recipe_id, stars } — never the user's name/email.
        let event = AnalyticsEvent.recipeRated(recipeID: 88, stars: 4)
        #expect(event.name == "recipe_rated")
        #expect(event.payload == ["recipe_id": "88", "stars": "4"])
        #expect(event.payload.keys.count == 2)
    }

    @Test func recipeCommentSubmittedCarriesRecipeIDAndModerationFlag() {
        // Spec AC-14.7 + constitution §9 (CL-21 amendment): payload is
        // exactly { recipe_id, awaiting_approval } — never the comment body.
        let approved = AnalyticsEvent.recipeCommentSubmitted(recipeID: 12, awaitingApproval: false)
        let held = AnalyticsEvent.recipeCommentSubmitted(recipeID: 12, awaitingApproval: true)
        #expect(approved.name == "recipe_comment_submitted")
        #expect(approved.payload == ["recipe_id": "12", "awaiting_approval": "false"])
        #expect(held.payload == ["recipe_id": "12", "awaiting_approval": "true"])
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
            AnalyticsEvent.cookModeStarted(recipeID: 1).name,
            AnalyticsEvent.recipeRated(recipeID: 1, stars: 5).name,
            AnalyticsEvent.recipeCommentSubmitted(recipeID: 1, awaitingApproval: false).name,
        ]
        #expect(Set(allNames).count == allNames.count)
    }
}

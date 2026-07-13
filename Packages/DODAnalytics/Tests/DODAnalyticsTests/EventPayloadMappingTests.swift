import Testing

@testable import DODAnalytics

/// Targeted tests for event → param mapping gaps not covered by existing
/// AnalyticsEventTests.swift. These cover:
/// - Four event payload contracts that lack explicit tests
/// - Exhaustive GA4 content-open filter across ALL event cases
@Suite("Event Payload Mapping") struct EventPayloadMappingTests {

    // MARK: - Uncovered event payload contracts

    @Test func recipeSavedCarriesRecipeID() {
        let event = AnalyticsEvent.recipeSaved(recipeID: 42)
        #expect(event.name == "recipe_saved")
        #expect(event.payload == ["recipe_id": "42"])
        #expect(event.payload.keys.count == 1)
    }

    @Test func recipeUnsavedCarriesRecipeID() {
        let event = AnalyticsEvent.recipeUnsaved(recipeID: 99)
        #expect(event.name == "recipe_unsaved")
        #expect(event.payload == ["recipe_id": "99"])
        #expect(event.payload.keys.count == 1)
    }

    @Test func recipeSharedCarriesRecipeID() {
        let event = AnalyticsEvent.recipeShared(recipeID: 17)
        #expect(event.name == "recipe_shared")
        #expect(event.payload == ["recipe_id": "17"])
        #expect(event.payload.keys.count == 1)
    }

    @Test func offlineReadCarriesRecipeID() {
        let event = AnalyticsEvent.offlineRead(recipeID: 333)
        #expect(event.name == "offline_read")
        #expect(event.payload == ["recipe_id": "333"])
        #expect(event.payload.keys.count == 1)
    }

    // MARK: - GA4 exhaustive content-open filter

    @Test func ga4MapsOnlyRecipeViewAndOfflineReadExhaustively() {
        // DUT-680: GA4 is ONLY for content opens. Sweep ALL 18 AnalyticsEvent
        // cases and verify that ONLY recipeView + offlineRead map to a GA4
        // event; every other case returns nil. This catches regressions where a
        // new event type accidentally gets wired to GA4 when it shouldn't.
        let allCases: [AnalyticsEvent] = [
            .appOpen,
            .screenView(name: "test"),
            .recipeView(recipeID: 1),  // ✓ should map
            .recipeSaved(recipeID: 1),
            .recipeUnsaved(recipeID: 1),
            .recipeSearched(queryHash: "hash"),
            .recipeShared(recipeID: 1),
            .offlineRead(recipeID: 1),  // ✓ should map
            .cookModeStarted(recipeID: 1),
            .recipeRated(recipeID: 1, stars: 5),
            .recipeCommentSubmitted(recipeID: 1, awaitingApproval: false),
            .widgetOpened(kind: .featured, recipeID: 1),
            .voiceModeToggled(on: true),
            .voiceCommandFired(command: .next),
            .syncEnabled,
            .syncDisabled,
            .syncCompletedSuccessfully,
            .syncFailed(errorCategory: .network),
        ]

        for event in allCases {
            verifyGA4EventMapping(event)
        }
    }

    /// Helper to reduce cyclomatic complexity of the exhaustive GA4 filter test.
    private func verifyGA4EventMapping(_ event: AnalyticsEvent) {
        let mapped = GA4Transport.ga4Event(for: event)
        let isRecipeOpen = isContentOpenEvent(event)

        if isRecipeOpen {
            #expect(
                mapped != nil,
                "Event \(eventName(event)) should map to GA4 but got nil"
            )
            #expect(mapped?.name == "recipe_open")
        } else {
            #expect(
                mapped == nil,
                "Event \(eventName(event)) should NOT map to GA4"
            )
        }
    }

    /// Identify if an event is a content-open (recipeView or offlineRead).
    private func isContentOpenEvent(_ event: AnalyticsEvent) -> Bool {
        switch event {
        case .recipeView, .offlineRead:
            true
        default:
            false
        }
    }

    // MARK: - GA4 params inclusion for both content-open variants

    @Test func recipeViewAndOfflineReadBothProduceGA4Params() {
        // Both recipeView and offlineRead should produce identical GA4 event
        // shape (post_id, app_platform, page_host, page_path).
        let recipeID = 42
        let recipeOpen = GA4Transport.ga4Event(for: .recipeView(recipeID: recipeID))
        let offlineOpen = GA4Transport.ga4Event(for: .offlineRead(recipeID: recipeID))

        #expect(recipeOpen != nil)
        #expect(offlineOpen != nil)

        guard let recipeParams = recipeOpen?.params,
            let offlineParams = offlineOpen?.params
        else {
            Issue.record("Both events should produce params")
            return
        }

        // Both should have the same parameter keys and values.
        #expect(recipeParams == offlineParams)
        #expect(recipeParams["post_id"] == String(recipeID))
        #expect(recipeParams["app_platform"] == "ios")
        #expect(recipeParams["page_host"] == "dutchovendaddy.com")
        #expect(recipeParams["page_path"] == "/recipe/\(recipeID)")
    }

    // MARK: - Helpers

    /// Return a human-readable name for an event (for error messages).
    /// Uses the event's canonical name property (snake_case wire format).
    private func eventName(_ event: AnalyticsEvent) -> String {
        event.name
    }

    /// Compare two AnalyticsEvent values structurally (by case and associated
    /// values). Kept simple to avoid cyclomatic complexity violations.
    /// This is a sanity check rather than perfect structural equality.
    private func eventEqualsStructurally(
        _ first: AnalyticsEvent,
        _ second: AnalyticsEvent
    ) -> Bool {
        // Use the enum's native Equatable implementation, which is correct.
        first == second
    }
}

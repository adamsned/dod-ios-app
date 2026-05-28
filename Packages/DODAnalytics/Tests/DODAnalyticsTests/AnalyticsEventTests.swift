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

    @Test func widgetOpenedFeaturedCarriesKindAndRecipeID() {
        // Spec AC-17.9 + constitution §9 (US-17 amendment): the featured
        // widget tap reports kind="featured" plus the integer recipe id.
        let event = AnalyticsEvent.widgetOpened(kind: .featured, recipeID: 42)
        #expect(event.name == "widget_opened")
        #expect(event.payload == ["kind": "featured", "recipe_id": "42"])
        #expect(event.payload.keys.count == 2)
    }

    @Test func widgetOpenedSavedRowCarriesKindAndRecipeID() {
        // Spec AC-17.9: saved-widget per-row tap reports kind="saved"
        // plus the integer recipe id of the row tapped.
        let event = AnalyticsEvent.widgetOpened(kind: .saved, recipeID: 99)
        #expect(event.payload == ["kind": "saved", "recipe_id": "99"])
    }

    @Test func widgetOpenedSavedChromeOmitsRecipeID() {
        // Spec AC-17.9 + AC-17.4 / AC-17.5: saved-widget chrome /
        // empty-state tap reports kind="saved" with **no** recipe id —
        // the tap landed on `dod://saved`, not a specific recipe.
        let event = AnalyticsEvent.widgetOpened(kind: .saved, recipeID: nil)
        #expect(event.name == "widget_opened")
        #expect(event.payload == ["kind": "saved"])
        #expect(event.payload["recipe_id"] == nil)
        #expect(event.payload.keys.count == 1)
    }

    @Test func widgetOpenedPayloadHasNoFreeText() {
        // Constitution §9: the widgetOpened allowlist amendment forbids
        // free-text payload. Sweep every (kind, recipeID) combination and
        // assert each value parses as a known enum case or an integer.
        let permittedKindValues = Set(WidgetKind.allCases.map(\.rawValue))
        let cases: [AnalyticsEvent] = [
            .widgetOpened(kind: .featured, recipeID: 1),
            .widgetOpened(kind: .featured, recipeID: nil),
            .widgetOpened(kind: .saved, recipeID: 1),
            .widgetOpened(kind: .saved, recipeID: nil),
        ]
        for event in cases {
            for (key, value) in event.payload {
                switch key {
                case "kind":
                    #expect(permittedKindValues.contains(value))
                case "recipe_id":
                    #expect(Int(value) != nil, "recipe_id must serialize as a decimal integer")
                default:
                    Issue.record("Unexpected payload key \(key) on widgetOpened — free text leaked")
                }
            }
        }
    }

    @Test func voiceModeToggledCarriesOnlyTheBoolean() {
        // Spec AC-40.8 + constitution §9 (CL-82 amendment): payload is exactly
        // { on } — no recipe id, no free text.
        let on = AnalyticsEvent.voiceModeToggled(on: true)
        let off = AnalyticsEvent.voiceModeToggled(on: false)
        #expect(on.name == "voice_mode_toggled")
        #expect(on.payload == ["on": "true"])
        #expect(off.payload == ["on": "false"])
        #expect(on.payload.keys.count == 1)
    }

    @Test func voiceCommandFiredCarriesOnlyTheClosedEnumString() {
        // Spec AC-40.5 / AC-40.8 + constitution §9 (CL-82 amendment): payload
        // is exactly { command } where command is one of the four fixed enum
        // strings — never the user's spoken phrase.
        let next = AnalyticsEvent.voiceCommandFired(command: .next)
        #expect(next.name == "voice_command_fired")
        #expect(next.payload == ["command": "next"])
        #expect(AnalyticsEvent.voiceCommandFired(command: .previous).payload == ["command": "previous"])
        #expect(AnalyticsEvent.voiceCommandFired(command: .repeat).payload == ["command": "repeat"])
        #expect(AnalyticsEvent.voiceCommandFired(command: .pause).payload == ["command": "pause"])
    }

    @Test func voiceCommandFiredPayloadHasNoFreeText() {
        // Constitution §9 (CL-82): sweep every command and assert the only
        // payload value is a known enum string — no raw spoken phrase leaks.
        let permitted = Set(VoiceCommandName.allCases.map(\.rawValue))
        for command in VoiceCommandName.allCases {
            let event = AnalyticsEvent.voiceCommandFired(command: command)
            for (key, value) in event.payload {
                #expect(key == "command")
                #expect(permitted.contains(value), "voice_command_fired leaked free text: \(value)")
            }
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
            AnalyticsEvent.cookModeStarted(recipeID: 1).name,
            AnalyticsEvent.recipeRated(recipeID: 1, stars: 5).name,
            AnalyticsEvent.recipeCommentSubmitted(recipeID: 1, awaitingApproval: false).name,
            AnalyticsEvent.widgetOpened(kind: .featured, recipeID: 1).name,
            AnalyticsEvent.voiceModeToggled(on: true).name,
            AnalyticsEvent.voiceCommandFired(command: .next).name,
        ]
        #expect(Set(allNames).count == allNames.count)
    }
}

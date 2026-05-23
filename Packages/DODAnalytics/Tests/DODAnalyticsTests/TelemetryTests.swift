import Testing

@testable import DODAnalytics

/// Telemetry.shared is process-global; tests must run one at a time
/// or they race over the transport swap.
@Suite("Telemetry facade", .serialized) struct TelemetryTests {

    @Test func startConfiguresTransportOnce() {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        Telemetry.shared.start(appID: "app-id-one")
        Telemetry.shared.start(appID: "app-id-two")  // ignored — idempotent
        #expect(recorder.configuredAppID == "app-id-one")
    }

    @Test func sendCapturesEventInOrder() {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        Telemetry.shared.send(.appOpen)
        Telemetry.shared.send(.recipeView(recipeID: 42))
        #expect(recorder.events == [.appOpen, .recipeView(recipeID: 42)])
    }

    @Test func sendBeforeStartDoesNotCrash() {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        // No `start` call.
        Telemetry.shared.send(.appOpen)
        #expect(recorder.events.count == 1)
    }

    @Test func searchEventPayloadContainsOnlyHash() {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        let hash = "00112233445566778899aabbccddeeff"
        Telemetry.shared.send(.recipeSearched(queryHash: hash))
        guard let captured = recorder.events.first else {
            Issue.record("expected one event")
            return
        }
        let payload = captured.payload
        #expect(payload["query_hash"] == hash)
        // Constitution §9: raw user input must never appear.
        for value in payload.values {
            #expect(!value.contains(" "))
        }
    }
}

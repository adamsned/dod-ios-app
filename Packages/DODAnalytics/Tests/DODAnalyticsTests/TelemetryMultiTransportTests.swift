import Testing

@testable import DODAnalytics

/// Test the Telemetry facade's multi-transport fan-out logic:
/// - addTransport registration (before and after start)
/// - send dispatch to primary + additional transports
/// - replaceTransport state reset
/// Telemetry.shared is process-global; tests must run serially.
@Suite("Telemetry multi-transport fan-out", .serialized) struct TelemetryMultiTransportTests {

    @Test func additionalTransportReceivesEventsAfterAddingBeforeStart() {
        let primary = RecordingTelemetryTransport()
        let additional = RecordingTelemetryTransport()

        Telemetry.shared.replaceTransport(primary)
        Telemetry.shared.addTransport(additional)
        Telemetry.shared.start(appID: "test-app")
        Telemetry.shared.send(.appOpen)
        Telemetry.shared.send(.recipeView(recipeID: 42))

        #expect(primary.events.count == 2)
        #expect(additional.events.count == 2)
        #expect(primary.events == [.appOpen, .recipeView(recipeID: 42)])
        #expect(additional.events == [.appOpen, .recipeView(recipeID: 42)])
    }

    @Test func addTransportAfterStartIsNoOp() {
        let primary = RecordingTelemetryTransport()
        let additional = RecordingTelemetryTransport()

        Telemetry.shared.replaceTransport(primary)
        Telemetry.shared.start(appID: "test-app")
        // addTransport after start is a no-op (idempotent with start's configured guard)
        Telemetry.shared.addTransport(additional)
        Telemetry.shared.send(.appOpen)

        #expect(primary.events.count == 1)
        #expect(additional.events.isEmpty)
    }

    @Test func multipleAdditionalTransportsAllReceiveEventsInOrder() {
        let primary = RecordingTelemetryTransport()
        let additional1 = RecordingTelemetryTransport()
        let additional2 = RecordingTelemetryTransport()
        let additional3 = RecordingTelemetryTransport()

        Telemetry.shared.replaceTransport(primary)
        Telemetry.shared.addTransport(additional1)
        Telemetry.shared.addTransport(additional2)
        Telemetry.shared.addTransport(additional3)
        Telemetry.shared.start(appID: "test-app")

        Telemetry.shared.send(.appOpen)
        Telemetry.shared.send(.recipeView(recipeID: 1))
        Telemetry.shared.send(.recipeSaved(recipeID: 2))

        let expectedEvents: [AnalyticsEvent] = [
            .appOpen,
            .recipeView(recipeID: 1),
            .recipeSaved(recipeID: 2),
        ]

        #expect(primary.events == expectedEvents)
        #expect(additional1.events == expectedEvents)
        #expect(additional2.events == expectedEvents)
        #expect(additional3.events == expectedEvents)
    }

    @Test func startConfiguresAllAdditionalTransportsAddedBeforeStart() {
        let primary = RecordingTelemetryTransport()
        let additional1 = RecordingTelemetryTransport()
        let additional2 = RecordingTelemetryTransport()

        Telemetry.shared.replaceTransport(primary)
        Telemetry.shared.addTransport(additional1)
        Telemetry.shared.addTransport(additional2)

        #expect(primary.configuredAppID == nil)
        #expect(additional1.configuredAppID == nil)
        #expect(additional2.configuredAppID == nil)

        Telemetry.shared.start(appID: "my-app-id")

        #expect(primary.configuredAppID == "my-app-id")
        #expect(additional1.configuredAppID == "my-app-id")
        #expect(additional2.configuredAppID == "my-app-id")
    }

    @Test func replaceTransportClearsAdditionalTransports() {
        let primary1 = RecordingTelemetryTransport()
        let additional1 = RecordingTelemetryTransport()
        let additional2 = RecordingTelemetryTransport()

        Telemetry.shared.replaceTransport(primary1)
        Telemetry.shared.addTransport(additional1)
        Telemetry.shared.addTransport(additional2)
        Telemetry.shared.start(appID: "app-one")
        Telemetry.shared.send(.appOpen)

        // Verify the fanout worked before replace
        #expect(primary1.events.count == 1)
        #expect(additional1.events.count == 1)
        #expect(additional2.events.count == 1)

        // Replace the transport
        let primary2 = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(primary2)

        // After replace, old transports stop receiving
        Telemetry.shared.send(.recipeView(recipeID: 99))

        #expect(primary1.events.count == 1)  // still has only the first event
        #expect(additional1.events.count == 1)  // still has only the first event
        #expect(additional2.events.count == 1)  // still has only the first event
        #expect(primary2.events.count == 1)  // new primary has only the second event
    }

    @Test func replaceTransportResetsConfiguredFlag() {
        let primary1 = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(primary1)
        Telemetry.shared.start(appID: "app-one")

        #expect(primary1.configuredAppID == "app-one")

        let primary2 = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(primary2)

        // After replace, configured is reset, so addTransport works again
        let additional = RecordingTelemetryTransport()
        Telemetry.shared.addTransport(additional)
        Telemetry.shared.start(appID: "app-two")

        #expect(primary2.configuredAppID == "app-two")
        #expect(additional.configuredAppID == "app-two")
    }

    @Test func sendDoesNotCrashWhenNoAdditionalTransportsAdded() {
        let primary = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(primary)
        Telemetry.shared.send(.appOpen)
        Telemetry.shared.send(.recipeView(recipeID: 5))

        #expect(primary.events.count == 2)
    }

    @Test func additionalTransportReceivesEventsSentBeforeFacadeStart() {
        let primary = RecordingTelemetryTransport()
        let additional = RecordingTelemetryTransport()

        Telemetry.shared.replaceTransport(primary)
        Telemetry.shared.addTransport(additional)

        // Send before start — both transports capture (production primary
        // gates itself; recording transports capture unconditionally)
        Telemetry.shared.send(.appOpen)

        Telemetry.shared.start(appID: "test-app")
        Telemetry.shared.send(.recipeView(recipeID: 7))

        #expect(primary.events.count == 2)
        #expect(additional.events.count == 2)
    }

    @Test func addTransportIdempotencyAcrossMultipleCalls() {
        let primary = RecordingTelemetryTransport()
        let additional1 = RecordingTelemetryTransport()
        let additional2 = RecordingTelemetryTransport()

        Telemetry.shared.replaceTransport(primary)
        Telemetry.shared.addTransport(additional1)
        Telemetry.shared.start(appID: "test-app")

        // After start, further addTransport calls are no-op
        Telemetry.shared.addTransport(additional2)
        Telemetry.shared.addTransport(additional1)  // duplicate

        Telemetry.shared.send(.appOpen)

        // Only primary and the first additional receive the event
        #expect(primary.events.count == 1)
        #expect(additional1.events.count == 1)
        #expect(additional2.events.isEmpty)
    }
}

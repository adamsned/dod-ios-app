import Foundation

/// The send-side seam between the `Telemetry` facade and the actual upstream
/// analytics provider. Production builds wire this to TelemetryDeck; tests
/// inject ``RecordingTelemetryTransport`` and assert on captured events.
public protocol TelemetryTransport: Sendable {
    /// Configure the upstream with an app/client identifier. Called once at app start.
    func configure(appID: String)
    /// Send one analytics event to the upstream. Must be cheap and non-blocking.
    func send(_ event: AnalyticsEvent)
}

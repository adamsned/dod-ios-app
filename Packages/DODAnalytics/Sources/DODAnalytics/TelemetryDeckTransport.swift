import Foundation
import TelemetryDeck

/// Production telemetry transport, backed by TelemetryDeck.
///
/// **TelemetryDeck is imported ONLY in this file** (constitution §9, plan §6).
/// Feature modules talk to ``Telemetry`` / ``AnalyticsEvent`` and never see
/// the upstream SDK. Replacing the provider is a one-file change.
public struct TelemetryDeckTransport: TelemetryTransport {

    public init() {}

    public func configure(appID: String) {
        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
    }

    public func send(_ event: AnalyticsEvent) {
        TelemetryDeck.signal(event.name, parameters: event.payload)
    }
}

import Foundation
import TelemetryDeck

/// Production telemetry transport, backed by TelemetryDeck.
///
/// **TelemetryDeck is imported ONLY in this file** (constitution §9, plan §6).
/// Feature modules talk to ``Telemetry`` / ``AnalyticsEvent`` and never see
/// the upstream SDK. Replacing the provider is a one-file change.
///
/// Calling `TelemetryDeck.signal()` before `initialize(config:)` is a fatal
/// error in the SDK — so the transport tracks its own configured state and
/// drops sends that arrive before configuration.
public final class TelemetryDeckTransport: TelemetryTransport, @unchecked Sendable {

    private let lock = NSLock()
    private var configured = false

    public init() {}

    public func configure(appID: String) {
        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
        lock.lock()
        configured = true
        lock.unlock()
    }

    public func send(_ event: AnalyticsEvent) {
        lock.lock()
        let isConfigured = configured
        lock.unlock()
        guard isConfigured else { return }
        TelemetryDeck.signal(event.name, parameters: event.payload)
    }
}

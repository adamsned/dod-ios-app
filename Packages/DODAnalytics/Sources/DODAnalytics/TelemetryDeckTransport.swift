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
///
/// **Privacy opt-out gate (US-36 / AC-36.5 / AC-36.6).** Every `send(_:)`
/// call reads the user's "Share anonymous usage data" preference from
/// `UserDefaults` (key ``telemetryEnabledKey``) and short-circuits before
/// the SDK call when the flag is false. The default-ON behavior is
/// `object(forKey:) as? Bool ?? true` so an absent key honors the
/// constitution §9 opt-out posture (telemetry on by default; user can
/// disable it from Settings → "Share anonymous usage data"). The gate
/// lives in the production transport — not in the ``Telemetry`` facade —
/// so ``RecordingTelemetryTransport`` (the test fixture) continues to
/// capture every event for L1 assertions; only the upstream wire path is
/// gated.
public final class TelemetryDeckTransport: TelemetryTransport, @unchecked Sendable {

    /// `UserDefaults` key for the privacy toggle. Authoritative copy
    /// lives in `SettingsViewModel.telemetryEnabledKey` (DODFeatureFeed);
    /// duplicated here as a literal string so this package doesn't have
    /// to depend on DODFeatureFeed (which would invert the dependency
    /// graph — Feature packages depend on Analytics, not vice versa).
    /// Both surfaces use the same literal `"dod.settings.telemetryEnabled"`.
    ///
    /// Spec trace: US-36 AC-36.5 / AC-36.6 — privacy opt-out gate.
    public static let telemetryEnabledKey = "dod.settings.telemetryEnabled"

    private let lock = NSLock()
    private var configured = false
    private let defaults: UserDefaults

    /// `defaults` defaults to `UserDefaults.standard` in production. The
    /// L1 unit tests inject an isolated suite via
    /// `UserDefaults(suiteName:)` so they can pin the gate's behavior
    /// without polluting the standard defaults.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func configure(appID: String) {
        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
        lock.lock()
        configured = true
        lock.unlock()
    }

    public func send(_ event: AnalyticsEvent) {
        // AC-36.5 / AC-36.6: gate read happens at every send so flipping
        // the toggle takes effect immediately on the next event. An
        // absent key falls back to `true` (default ON) — matches the
        // constitution §9 opt-out posture.
        guard isTelemetryEnabled() else { return }
        lock.lock()
        let isConfigured = configured
        lock.unlock()
        guard isConfigured else { return }
        TelemetryDeck.signal(event.name, parameters: event.payload)
    }

    /// Read the user's privacy toggle, defaulting to `true` when absent.
    /// Exposed as a method (not a property) so the read happens at
    /// call-time — a parallel mutation from `SettingsViewModel` lands
    /// here on the next event without any observation plumbing.
    private func isTelemetryEnabled() -> Bool {
        (defaults.object(forKey: Self.telemetryEnabledKey) as? Bool) ?? true
    }
}

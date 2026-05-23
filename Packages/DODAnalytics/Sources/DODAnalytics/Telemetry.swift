import Foundation

/// Process-wide telemetry facade. Feature code calls `Telemetry.shared.send(.recipeView(...))`
/// and never imports TelemetryDeck directly.
///
/// Set up once at app launch by the composition root (T-140):
/// ```swift
/// Telemetry.shared.start(appID: "...")
/// ```
public final class Telemetry: @unchecked Sendable {

    /// Singleton facade. Singleton is acceptable here because the transport is
    /// inherently process-wide (one upstream client). For test isolation,
    /// inject ``RecordingTelemetryTransport`` via ``replaceTransport(_:)``.
    public static let shared = Telemetry()

    private let lock = NSLock()
    private var transport: TelemetryTransport = TelemetryDeckTransport()
    private var configured = false

    private init() {}

    /// Configure the upstream transport. Idempotent; later calls are ignored.
    public func start(appID: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !configured else { return }
        transport.configure(appID: appID)
        configured = true
    }

    /// Send a single event. Safe to call before ``start(appID:)`` — the
    /// production transport guards itself against uninitialized sends; the
    /// test recording transport captures unconditionally.
    public func send(_ event: AnalyticsEvent) {
        lock.lock()
        let transport = self.transport
        lock.unlock()
        transport.send(event)
    }

    /// Replace the transport. Intended for tests only; the production
    /// composition root never calls this.
    public func replaceTransport(_ transport: TelemetryTransport) {
        lock.lock()
        defer { lock.unlock() }
        self.transport = transport
        configured = false
    }
}

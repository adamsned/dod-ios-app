import Foundation

/// In-memory transport for tests. Records every event sent so test assertions
/// can verify the wire format without contacting a real upstream.
public final class RecordingTelemetryTransport: TelemetryTransport, @unchecked Sendable {

    private let lock = NSLock()
    private var _events: [AnalyticsEvent] = []
    private var _configuredAppID: String?

    public init() {}

    public func configure(appID: String) {
        lock.lock()
        defer { lock.unlock() }
        _configuredAppID = appID
    }

    public func send(_ event: AnalyticsEvent) {
        lock.lock()
        defer { lock.unlock() }
        _events.append(event)
    }

    public var events: [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    public var configuredAppID: String? {
        lock.lock()
        defer { lock.unlock() }
        return _configuredAppID
    }
}

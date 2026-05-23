import Foundation
import OSLog

/// Category-segmented OSLog facade. Use the static accessors rather than
/// constructing your own — keeps subsystems consistent across the codebase.
///
/// Redaction note: never log user-typed strings directly (search queries,
/// recipe titles a user composed, etc). Use ``redact(_:)`` first.
public enum DODLog {

    private static let subsystem = "com.dutchovendaddy.DODApp"

    /// HTTP traffic, parser results, connectivity changes.
    public static let network = Logger(subsystem: subsystem, category: "network")

    /// SwiftData reads/writes, cache evictions.
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// View-model state transitions, nav events.
    public static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Telemetry sends (events themselves never include redacted content).
    public static let analytics = Logger(subsystem: subsystem, category: "analytics")

    /// General-purpose fallback. Prefer a specific category.
    public static let app = Logger(subsystem: subsystem, category: "app")

    /// Replace anything you wouldn't show to a stranger with `<redacted>`.
    /// Use this before logging user-typed strings like search queries.
    public static func redact(_ value: String) -> String {
        value.isEmpty ? "<empty>" : "<redacted:\(value.count)>"
    }
}

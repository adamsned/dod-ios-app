import Foundation

/// DUT-996 — local-only log of diner reactions. `@unchecked Sendable` for the
/// same reason as ``PanCareStore`` (a `let UserDefaults` is thread-safe).
public struct OneBiteStore: @unchecked Sendable {
    static let key = "dod.oneBite.entries"
    /// Cap so the blob stays small.
    static let maxEntries = 500
    private let defaults: UserDefaults

    /// Test seam — inject a throwaway `UserDefaults(suiteName:)`.
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Newest first.
    public func entries() -> [DinerReactionEntry] {
        guard let data = defaults.data(forKey: Self.key),
            let decoded = try? JSONDecoder().decode([DinerReactionEntry].self, from: data)
        else { return [] }
        return decoded.sorted { $0.loggedAt > $1.loggedAt }
    }

    public func add(_ entry: DinerReactionEntry) {
        let updated = Array(([entry] + entries()).sorted { $0.loggedAt > $1.loggedAt }.prefix(Self.maxEntries))
        if let data = try? JSONEncoder().encode(updated) { defaults.set(data, forKey: Self.key) }
    }
}

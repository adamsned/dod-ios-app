import Foundation

/// Small persistent ring of the user's last N search queries, oldest at the
/// back. Backed by `UserDefaults` to avoid bumping the SwiftData schema for
/// what is essentially a UX-quality cache that survives reinstall-loss with
/// no impact.
///
/// Privacy: the raw query is stored locally on-device only. It is never sent
/// to telemetry — the analytics path continues to send only
/// `StringHasher.sha256Hex` of the query per AC-3.6.
///
/// Spec trace: US-12 / AC-12.4 (recent history persists).
public final class RecentSearches: @unchecked Sendable {

    /// Maximum number of entries retained. Older entries are evicted as
    /// new ones land at the front.
    public static let maxEntries = 10

    /// UserDefaults key. The `V1` suffix mirrors the onboarding-flag
    /// convention so a future format change can rotate to `V2` without
    /// shipping a migrator.
    public static let storageKey = "dod.recentSearchesV1"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, storageKey: String = RecentSearches.storageKey) {
        self.defaults = defaults
        self.key = storageKey
    }

    /// Newest-first ordered list of stored queries.
    public func recent() -> [String] {
        (defaults.array(forKey: key) as? [String]) ?? []
    }

    /// Move `query` to the front (creating it if new), dedupe
    /// case-insensitively, and trim to ``maxEntries``. Empty / whitespace-only
    /// queries are ignored.
    public func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var current = recent()
        current.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        current.insert(trimmed, at: 0)
        if current.count > Self.maxEntries {
            current = Array(current.prefix(Self.maxEntries))
        }
        defaults.set(current, forKey: key)
    }

    /// Wipe the history (e.g. for a future "Clear recents" affordance).
    public func clear() {
        defaults.removeObject(forKey: key)
    }
}

import DODDomain
import Foundation

/// Persists the highest announcement id the cook has seen (DUT-147).
/// UserDefaults-backed like the Settings preferences; the key is the on-disk wire format, never rename it.
public struct AnnouncementReadTracker: Sendable {
    static let key = "fromNed.lastReadAnnouncementID"
    nonisolated(unsafe) private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var lastReadID: Int { defaults.integer(forKey: Self.key) }

    public func unreadCount(in items: [Announcement]) -> Int {
        items.filter { $0.id > lastReadID }.count
    }

    /// Mark everything currently listed as read (called when the feed opens).
    public func markAllRead(_ items: [Announcement]) {
        guard let maxID = items.map(\.id).max(), maxID > lastReadID else { return }
        defaults.set(maxID, forKey: Self.key)
    }
}

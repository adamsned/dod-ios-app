import Foundation

/// DUT-976 — a day's worth of cooks treated as one gathering.
public struct CookoutGroup: Identifiable, Equatable, Sendable {
    /// Start of the calendar day, which doubles as the identity.
    public let day: Date
    /// Entries cooked that day, oldest first.
    public let entries: [CookLogEntry]
    public var id: Date { day }
    public var dishCount: Int { entries.count }
    /// Average of the personal ratings that exist; nil if none are rated.
    public var averageRating: Double? { CookLogStats.averageRating(entries) }
    /// Entries that have a photo, in cook order.
    public var photoIDs: [String] { entries.compactMap(\.photoLocalID) }
}

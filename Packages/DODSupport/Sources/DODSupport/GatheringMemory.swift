import Foundation

/// DUT-978 — one gathering's guest ledger: headcount, optional named guests,
/// and which logged dishes (CookLogEntry.id) were "the hit". Private, local-only.
public struct GatheringRecord: Identifiable, Sendable, Equatable {
    public let id: UUID
    /// Start of the gathering's day (matches CookoutGroup.day).
    public let day: Date
    public let headcount: Int
    public let guestNames: [String]
    public let hitEntryIDs: [UUID]

    public init(
        id: UUID,
        day: Date,
        headcount: Int,
        guestNames: [String] = [],
        hitEntryIDs: [UUID] = []
    ) {
        self.id = id
        self.day = day
        self.headcount = max(0, headcount)
        self.guestNames =
            guestNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.hitEntryIDs = hitEntryIDs
    }
}

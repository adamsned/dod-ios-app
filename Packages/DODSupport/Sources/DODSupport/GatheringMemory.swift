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

/// One recommended "cook the hits again" dish.
public struct HitDish: Identifiable, Sendable, Equatable {
    public let recipeID: Int
    public let recipeTitle: String
    /// How many gatherings marked this recipe a hit.
    public let hitCount: Int
    public var id: Int { recipeID }

    public init(recipeID: Int, recipeTitle: String, hitCount: Int) {
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.hitCount = hitCount
    }
}

public enum GatheringMemory {
    /// Recipes marked as hits across gatherings, most-hit first (ties: title A-Z).
    /// A gathering's hitEntryIDs are resolved against `entries`; unknown ids are ignored.
    /// Counts at most one hit per recipe per gathering.
    public static func hits(
        records: [GatheringRecord],
        entries: [CookLogEntry],
        limit: Int = 5
    ) -> [HitDish] {
        let byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var counts: [Int: (title: String, count: Int)] = [:]
        for record in records {
            let recipes = Set(record.hitEntryIDs.compactMap { byID[$0] }.map(\.recipeID))
            for recipeID in recipes {
                let title = entries.first { $0.recipeID == recipeID }?.recipeTitle ?? ""
                counts[recipeID] = (title, (counts[recipeID]?.count ?? 0) + 1)
            }
        }
        return Array(
            counts
                .map { HitDish(recipeID: $0.key, recipeTitle: $0.value.title, hitCount: $0.value.count) }
                .sorted { $0.hitCount != $1.hitCount ? $0.hitCount > $1.hitCount : $0.recipeTitle < $1.recipeTitle }
                .prefix(max(0, limit))
        )
    }
}

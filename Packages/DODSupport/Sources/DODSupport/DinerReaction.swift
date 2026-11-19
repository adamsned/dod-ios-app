import Foundation

/// DUT-996 — a diner's reaction to a new food (distinct from the cook-facing
/// `CookLogEntry.note` / `personalRating`).
public enum OneBiteReaction: String, CaseIterable, Sendable, Codable, Equatable {
    case notYet, tried, liked

    public var title: String {
        switch self {
        case .notYet: return "Not yet"
        case .tried: return "Tried it"
        case .liked: return "Liked it"
        }
    }

    /// True when the diner actually took a bite (tried or liked).
    public var countsAsTried: Bool { self != .notYet }
}

public struct DinerReactionEntry: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    /// Stable key for the diner (the Table Roster maps its own id/name onto this).
    public let dinerKey: String
    public let dinerName: String
    public let recipeID: Int
    public let recipeTitle: String
    public let reaction: OneBiteReaction
    public let loggedAt: Date

    public init(
        id: UUID = UUID(),
        dinerKey: String,
        dinerName: String,
        recipeID: Int,
        recipeTitle: String,
        reaction: OneBiteReaction,
        loggedAt: Date
    ) {
        self.id = id
        self.dinerKey = dinerKey
        self.dinerName = dinerName
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.reaction = reaction
        self.loggedAt = loggedAt
    }
}

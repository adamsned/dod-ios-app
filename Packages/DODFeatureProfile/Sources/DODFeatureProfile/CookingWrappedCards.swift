import DODSupport
import Foundation

/// DUT-177 — one friendly recap card.
public struct CookingWrappedCard: Identifiable, Equatable, Sendable {
    public let id: String
    public let emoji: String
    public let headline: String
    public let detail: String

    public init(id: String, emoji: String, headline: String, detail: String) {
        self.id = id
        self.emoji = emoji
        self.headline = headline
        self.detail = detail
    }
}

public enum CookingWrappedCards {
    /// Below this many cooks we show one encouraging card instead of stats.
    public static let lowDataThreshold = 3

    /// The single gentle card shown when there is too little data for stats.
    static func lowDataCard(totalCooks: Int) -> CookingWrappedCard {
        CookingWrappedCard(
            id: "low-data",
            emoji: "🌱",
            headline: totalCooks == 0 ? "Your cooking story starts here" : "A great start",
            detail: "Every meal you log adds to your story. Cook something tasty and it will show up here."
        )
    }
}

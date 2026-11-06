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

    /// Returns the appropriate cards for a given wrapped data.
    public static func cards(
        for wrapped: CookingWrapped,
        calendar: Calendar = .current
    ) -> [CookingWrappedCard] {
        if wrapped.totalCooks < lowDataThreshold {
            return [lowDataCard(totalCooks: wrapped.totalCooks)]
        }
        var cards = [
            CookingWrappedCard(
                id: "total",
                emoji: "🍽️",
                headline: "\(wrapped.totalCooks) meals on the table",
                detail: "Thank you for cooking with us."
            )
        ]
        if let top = wrapped.mostCooked {
            cards.append(
                CookingWrappedCard(
                    id: "most-cooked",
                    emoji: "🏆",
                    headline: top.title,
                    detail: "Your go-to, cooked \(top.count) times."
                )
            )
        }
        if let category = wrapped.topCategory {
            cards.append(
                CookingWrappedCard(
                    id: "category",
                    emoji: "🥘",
                    headline: category,
                    detail: "Your favorite kind of cooking this year."
                )
            )
        }
        return cards
    }
}

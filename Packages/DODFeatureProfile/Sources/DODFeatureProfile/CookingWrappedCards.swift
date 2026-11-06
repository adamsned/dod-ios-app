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

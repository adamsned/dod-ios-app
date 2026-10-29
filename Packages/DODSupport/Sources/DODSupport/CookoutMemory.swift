import Foundation

/// DUT-965 — the captured story of a finished cookout.
public struct CookoutMemory: Codable, Sendable, Equatable, Identifiable {
    public enum Reaction: String, Codable, Sendable, CaseIterable {
        case loved, seconds, askedForRecipe
    }

    public let id: UUID
    public let planID: UUID
    public let planName: String
    public let guestCount: Int
    public let dishTitles: [String]
    /// Filenames of photos saved by the capture UI (not image data).
    public var photoFilenames: [String]
    public var reactions: [Reaction]

    public init(id: UUID = UUID(), plan: CookoutPlan, photoFilenames: [String] = [], reactions: [Reaction] = []) {
        self.id = id
        self.planID = plan.id
        self.planName = plan.name
        self.guestCount = plan.guestCount
        self.dishTitles = plan.dishes.map(\.title)
        self.photoFilenames = photoFilenames
        self.reactions = reactions
    }

    public func count(of reaction: Reaction) -> Int {
        reactions.filter { $0 == reaction }.count
    }

    /// One-line story, e.g. "Fed 12 with Chili & Cobbler — 3 asked for the recipe".
    public var headline: String {
        let dishes = dishTitles.joined(separator: " & ")
        var line = "Fed \(guestCount)" + (dishes.isEmpty ? "" : " with \(dishes)")
        let asks = count(of: .askedForRecipe)
        if asks > 0 { line += " — \(asks) asked for the recipe" }
        return line
    }
}

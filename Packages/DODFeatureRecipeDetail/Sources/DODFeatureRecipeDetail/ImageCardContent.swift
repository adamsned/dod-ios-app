import DODDomain
import Foundation

/// DUT-123: text for the branded share image card.
struct ImageCardContent: Equatable {
    let title: String
    /// e.g. ["45 min", "Serves 6"]; empty when the recipe has neither.
    let stats: [String]
    /// Shown at the bottom of the card, e.g. "dutchovendaddy.com/pot-roast".
    let linkText: String
    /// What the QR encodes: the web URL.
    let qrPayload: String

    init(recipe: Recipe) {
        title = recipe.title
        var stats: [String] = []
        if let minutes = Self.minutes(recipe.cookTime ?? recipe.totalTime) {
            stats.append("\(minutes) min")
        }
        if let servings = recipe.servings, servings > 0 {
            stats.append("Serves \(servings)")
        }
        self.stats = stats
        qrPayload = recipe.canonicalURL.absoluteString
        linkText = (recipe.canonicalURL.host ?? "") + recipe.canonicalURL.path
    }

    private static func minutes(_ duration: Duration?) -> Int? {
        guard let duration else { return nil }
        let seconds = duration.components.seconds
        return seconds > 0 ? Int((seconds + 59) / 60) : nil
    }
}

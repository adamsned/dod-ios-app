import DODSupport
import Foundation

/// DUT-966 — the text on a "Share Your Win" capability-story card, derived from a
/// Cook Journal entry. Foundation-only so it is testable on the macOS `swift test` slice.
struct CookWinCardContent: Equatable {
    static let attribution = "Made with Dutch Oven Daddy"

    let dishTitle: String
    /// The cook's win in their own words (first non-empty line of the note), or nil.
    let win: String?

    init(entry: CookLogEntry) {
        dishTitle = entry.recipeTitle
        win = nil  // note parsing is added in the next sub-ticket
    }

    /// Big line on the card: the win if the cook wrote one, else "I made <dish>!".
    var headline: String { win ?? "I made \(dishTitle)!" }
}

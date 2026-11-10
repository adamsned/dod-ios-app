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
        let firstLine = (entry.note ?? "")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        win = firstLine.map { String($0.prefix(140)) }
    }

    /// Big line on the card: the win if the cook wrote one, else "I made <dish>!".
    var headline: String { win ?? "I made \(dishTitle)!" }

    /// Text sent alongside the image in the share sheet.
    var shareCaption: String { "\(headline) — \(Self.attribution)" }
}

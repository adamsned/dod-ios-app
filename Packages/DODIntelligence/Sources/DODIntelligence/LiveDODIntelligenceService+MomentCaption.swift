import Foundation

// The on-device Hero Moment caption turn (DUT-1008), split out of
// `LiveDODIntelligenceService.swift` like the substitution turn.
extension LiveDODIntelligenceService {

    /// Pure (testable on macOS): the user turn for a moment caption. The note is capped at 1000 chars.
    static func momentCaptionPrompt(for request: MomentCaptionRequest) -> String {
        var lines = ["Dish: \(request.recipeTitle)"]
        if let rating = request.personalRating { lines.append("Cook's own rating: \(rating) of 5") }
        if let note = request.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            lines.append("Cook's private note: \(String(note.prefix(1000)))")
        }
        lines.append("Write the caption now.")
        return lines.joined(separator: "\n")
    }
}

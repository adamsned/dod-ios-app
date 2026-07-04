import DODSupport
import Foundation

/// Bake-timer countdown formatting for ``FirstCookoutView`` (DUT-100 /
/// DUT-401), extracted so `FirstCookoutView+Stages.swift` stays under the
/// SwiftLint `file_length` cap.
extension FirstCookoutView {

    // MARK: Campfire-aware copy (DUT-192) — dish-agnostic phrasing for the
    // capstone; "Take It to the Campfire" only reads well as a title. Moved here
    // from `+Stages.swift` for the file_length cap (DUT-548/209 growth).

    var sharePreviewTitle: String {
        cookout.isCampfire ? "My campfire cook" : "My \(cookout.dishTitle)"
    }

    var recipeLinkLabel: String {
        cookout.isCampfire ? "Open the heat & coals guide" : "Open the \(cookout.dishTitle) recipe"
    }

    var bakeTimerLabel: String {
        cookout.isCampfire ? "Campfire cook" : "\(cookout.dishTitle) bake"
    }

    var bakeStepAwayText: String {
        cookout.isCampfire
            ? "Your cook is going, you can step away"
            : "\(cookout.dishTitle) bake, you can step away"
    }

    var goCheckText: String {
        cookout.isCampfire ? "Go check your Dutch oven." : "Go check your \(cookout.dishTitle)."
    }

    /// The share-sheet caption for a completed cook (moved here from the main
    /// struct body for the type_body_length cap — DUT-484).
    ///
    /// DUT-211 — gate the wording on the cook's position, not just campfire: only
    /// the first rung reads "I made my first …". `FirstCookoutView` is reused for
    /// rung 2 (chicken) and every dump cake, so a blanket "first" was a lie there.
    var shareCaption: String {
        if cookout.isCampfire {
            return "I cooked at the campfire with @dutchovendaddy! 🔥 #DutchOvenDaddy"
        }
        let dish = cookout.dishTitle
        return cookout.isFirstRung
            ? "I made my first \(dish) with @dutchovendaddy! 🔥 #DutchOvenDaddy"
            : "I made \(dish) with @dutchovendaddy! 🔥 #DutchOvenDaddy"
    }

    /// DUT-211 — the ShareLink subject, computed the same way as ``shareCaption``
    /// so a rung-2 / dump-cake share doesn't claim "My first Dutch oven cook".
    var shareSubject: String {
        cookout.isFirstRung ? "My first Dutch oven cook" : "My Dutch oven cook"
    }

    func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// DUT-401 — spell out the bake countdown for VoiceOver ("5 minutes 3
    /// seconds remaining") instead of letting it read the "5:03" digits.
    func bakeCountdownLabel(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let minutes = total / 60
        let secs = total % 60
        if minutes > 0 && secs > 0 { return "\(minutes) minutes \(secs) seconds remaining" }
        if minutes > 0 { return "\(minutes) minutes remaining" }
        return "\(secs) seconds remaining"
    }
}

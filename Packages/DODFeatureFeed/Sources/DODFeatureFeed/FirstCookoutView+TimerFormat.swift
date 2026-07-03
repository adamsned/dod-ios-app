import Foundation

/// Bake-timer countdown formatting for ``FirstCookoutView`` (DUT-100 /
/// DUT-401), extracted so `FirstCookoutView+Stages.swift` stays under the
/// SwiftLint `file_length` cap.
extension FirstCookoutView {

    /// The share-sheet caption for a completed cook (moved here from the main
    /// struct body for the type_body_length cap — DUT-484).
    var shareCaption: String {
        cookout.isCampfire
            ? "I cooked at the campfire with @dutchovendaddy! 🔥 #DutchOvenDaddy"
            : "I made my first \(cookout.dishTitle) with @dutchovendaddy! 🔥 #DutchOvenDaddy"
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

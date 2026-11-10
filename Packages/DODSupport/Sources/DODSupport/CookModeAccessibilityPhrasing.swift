import Foundation

/// DUT-116 — cooking-grammar strings for VoiceOver labels, hints and
/// announcements. Pure so TTS and VoiceOver share one phrasing.
public enum CookModeAccessibilityPhrasing {

    /// "Step 3 of 8. Sear the short ribs 4 minutes per side."
    public static func stepLabel(number: Int, total: Int, text: String) -> String {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = "Step \(number) of \(max(total, number))"
        return body.isEmpty ? "\(head)." : "\(head). \(body)"
    }

    public static func stepHint(isLastStep: Bool) -> String {
        isLastStep
            ? "Use the Advance action to finish cooking."
            : "Use the Advance to next step action to continue."
    }

    /// Spoken when the step changes. While Voice Mode is reading the body
    /// aloud, only a short position cue is announced (DUT-441).
    public static func stepChangeAnnouncement(
        number: Int,
        total: Int,
        text: String,
        voiceModeOn: Bool
    ) -> String {
        voiceModeOn
            ? "Step \(number) of \(max(total, number))"
            : stepLabel(number: number, total: total, text: text)
    }

    public static func timerCompleteAnnouncement(stepNumber: Int) -> String {
        "Timer complete for step \(stepNumber)."
    }

    /// 270 -> "4 minutes 30 seconds remaining"; 60 -> "1 minute remaining".
    public static func timerStatus(remainingSeconds: Int) -> String {
        let total = max(remainingSeconds, 0)
        let minutes = total / 60
        let seconds = total % 60
        var parts: [String] = []
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds) second\(seconds == 1 ? "" : "s")") }
        return parts.joined(separator: " ") + " remaining"
    }

    public static func ingredientsSummary(_ ingredients: [String]) -> String {
        ingredients.isEmpty
            ? "No listed ingredients for this step."
            : "Ingredients for this step: " + ingredients.joined(separator: ", ") + "."
    }
}

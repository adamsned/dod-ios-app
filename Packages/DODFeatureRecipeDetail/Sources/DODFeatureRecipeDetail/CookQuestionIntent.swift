import Foundation

/// DUT-1029 — what a hands-free utterance means in Cook Mode.
public enum CookQuestionIntent: Equatable, Sendable {
    case nextStep
    case previousStep
    case repeatStep
    case ask(String)  // open question, routed to the grounded assistant
    case empty

    public static func classify(_ transcript: String) -> CookQuestionIntent {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .empty }
        let lower = text.lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        let next: Set<String> = ["next", "next step", "what's next", "what is next", "whats next", "go on", "continue"]
        let back: Set<String> = ["back", "previous", "previous step", "go back"]
        let again: Set<String> = ["repeat", "repeat that", "say that again", "again"]
        if next.contains(lower) { return .nextStep }
        if back.contains(lower) { return .previousStep }
        if again.contains(lower) { return .repeatStep }
        return .ask(text)
    }
}

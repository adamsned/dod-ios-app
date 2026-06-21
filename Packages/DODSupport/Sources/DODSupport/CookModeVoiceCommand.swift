import Foundation

/// A recognized hands-free Cook Mode command (US-49 / DUT-101).
///
/// The speech layer (an `SFSpeechRecognizer` slice, later) feeds raw
/// transcripts to ``parse(_:)``. Keeping the mapping a pure function makes the
/// command grammar fully unit-testable without a microphone — and lets the same
/// grammar back a typed/remote control if ever needed. `.startTimer` is the
/// hook into the timer engine (DUT-100); `.next`/`.previous` drive Cook Mode
/// navigation; `.repeatStep` re-reads the current step via TTS.
public enum CookModeVoiceCommand: Sendable, Equatable, CaseIterable {
    case next
    case previous
    case repeatStep
    case startTimer
    case pause
    /// Nothing in the grammar matched — the caller ignores it (no accidental action).
    case unknown

    /// Map a recognized speech transcript to a command. Case-insensitive and
    /// whitespace-trimmed; matches a small set of natural synonyms. More
    /// specific phrases are checked first so "start a timer" can't be misread as
    /// a navigation command. Returns ``unknown`` when nothing matches.
    public static func parse(_ transcript: String) -> CookModeVoiceCommand {
        let text = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .unknown }

        // Order matters — most specific first.
        if matches(text, ["start a timer", "start the timer", "set a timer", "set timer", "start timer"]) {
            return .startTimer
        }
        if matches(text, ["repeat", "say that again", "read that again", "what was that", "again"]) {
            return .repeatStep
        }
        if matches(text, ["next step", "next", "go on", "continue", "move on", "forward"]) {
            return .next
        }
        if matches(text, ["previous step", "previous", "go back", "back", "last step"]) {
            return .previous
        }
        if matches(text, ["pause", "hold on", "wait", "stop"]) {
            return .pause
        }
        return .unknown
    }

    /// True when `text` equals any of `phrases`, or contains one as a substring
    /// (so "go to the next one" still resolves to `next`).
    private static func matches(_ text: String, _ phrases: [String]) -> Bool {
        for phrase in phrases where text == phrase || text.contains(phrase) {
            return true
        }
        return false
    }
}

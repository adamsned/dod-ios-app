import Foundation

/// DUT-986 — first-cook-only "training wheels": extra reassurance + a more
/// explicit checkpoint at the two highest-anxiety step kinds. Pure so the
/// classification and copy are unit-testable without SwiftUI.
public enum TrainingWheels {

    public enum Kind: Equatable, Sendable { case heatSetup, doneness }

    public struct Note: Equatable, Sendable {
        public let kind: Kind
        public let reassurance: String
        public let checkpoint: String
    }

    private static let donenessKeywords = [
        "done", "golden", "toothpick", "clean", "internal temp", "until", "bubbling", "set in the center",
    ]

    /// Heat setup wins over doneness when a step is both (e.g. "preheat... until").
    public static func kind(forStepText text: String) -> Kind? {
        if CookModeView.stepIsHeatRelated(text) { return .heatSetup }
        let haystack = text.lowercased()
        if donenessKeywords.contains(where: haystack.contains) { return .doneness }
        return nil
    }

    /// `nil` unless this is the user's very first cook AND the step is high-anxiety.
    public static func note(forStepText text: String, isFirstCookEver: Bool) -> Note? {
        guard isFirstCookEver, let kind = kind(forStepText: text) else { return nil }
        switch kind {
        case .heatSetup:
            return Note(
                kind: kind,
                reassurance:
                    "Coal heat feels fiddly the first time — everyone fusses here. Close enough is fine; you can adjust as you go.",
                checkpoint:
                    "Checkpoint: lid on, coals placed as described? Wait a few minutes before changing anything."
            )
        case .doneness:
            return Note(
                kind: kind,
                reassurance: "Trust your eyes and nose — this is the step where most first-timers worry too early.",
                checkpoint:
                    "Checkpoint: check the doneness cue in this step. Not there yet? Put the lid back and look again in 5 minutes."
            )
        }
    }
}

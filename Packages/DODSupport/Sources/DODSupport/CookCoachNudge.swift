import Foundation

/// DUT-967 — real-time Cook Mode coaching. Pure decision helper: given where the
/// cook is, return ONE short, calm nudge (or nil). Frames everything as
/// reassurance, never a rule.
public enum CookCoachNudge {

    public struct Context: Equatable, Sendable {
        public var stepIndex: Int
        public var stepCount: Int
        public var timerRunning: Bool
        public var timerCompleted: Bool
        public init(stepIndex: Int, stepCount: Int, timerRunning: Bool = false, timerCompleted: Bool = false) {
            self.stepIndex = stepIndex
            self.stepCount = stepCount
            self.timerRunning = timerRunning
            self.timerCompleted = timerCompleted
        }
    }

    /// Max characters, so the nudge fits the ~4KB ActivityKit ContentState limit.
    public static let maxLength = 120

    public static func nudge(for context: Context) -> String? {
        guard context.stepCount > 0,
            context.stepIndex >= 0,
            context.stepIndex < context.stepCount
        else { return nil }
        let text: String
        if context.timerCompleted {
            text = "Nice work — that timer's done. Take a breath, then check by feel."
        } else if context.stepIndex == context.stepCount - 1 {
            text = "Last step — you're doing great. Trust what you see and smell."
        } else if context.stepIndex == 0 {
            text = "You've got this. Take it one step at a time."
        } else if context.timerRunning {
            text = "You're doing great — the oven's working. Just keep an eye on the coals."
        } else {
            text = "You're doing great — ready when you are for the next step."
        }
        return String(text.prefix(maxLength))
    }
}

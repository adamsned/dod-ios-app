import Foundation

/// Supplies an LLM-derived extraction for one step's text; `nil` when unavailable.
public protocol StepTimerLLMExtracting: Sendable {
    func extract(from text: String) async -> StepTimerExtraction?
}

public struct StepTimerExtractor: Sendable {
    private let llm: (any StepTimerLLMExtracting)?
    public init(llm: (any StepTimerLLMExtracting)? = nil) { self.llm = llm }

    /// Heuristic first. The LLM supplements ONLY when the heuristic found no timer.
    public func extract(from text: String) async -> StepTimerExtraction {
        let base = StepTimerExtraction.heuristic(from: text)
        guard base.timers.isEmpty, let llm, let candidate = await llm.extract(from: text) else {
            return base
        }
        let accepted = Self.gate(candidate, against: text)
        return StepTimerExtraction(
            timers: accepted.timers,
            temperatureF: base.temperatureF ?? accepted.temperatureF
        )
    }

    /// Confidence gate: keep a timer only if its seconds are in range AND the step
    /// text contains a number or time word the model could have read it from.
    static func gate(_ candidate: StepTimerExtraction, against text: String) -> StepTimerExtraction {
        let lower = text.lowercased()
        let hasTimeWord = ["second", "sec", "minute", "min", "hour", "hr"].contains { lower.contains($0) }
        let timers =
            hasTimeWord
            ? candidate.timers.filter { StepTimerExtraction.secondsRange.contains($0.seconds) }.prefix(2)
            : []
        let temp = candidate.temperatureF.flatMap {
            StepTimerExtraction.temperatureFRange.contains($0) ? $0 : nil
        }
        return StepTimerExtraction(timers: Array(timers), temperatureF: temp)
    }
}

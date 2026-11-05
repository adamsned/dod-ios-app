import Foundation

/// One timer found in a recipe step. DUT-1025.
public struct StepTimer: Sendable, Equatable, Hashable {
    public let label: String
    public let seconds: Int
    public init(label: String, seconds: Int) {
        self.label = label
        self.seconds = seconds
    }
}

/// Timers and oven/pan temperature extracted from ONE `RecipeInstruction.text`.
public struct StepTimerExtraction: Sendable, Equatable {
    public let timers: [StepTimer]
    public let temperatureF: Int?
    public init(timers: [StepTimer], temperatureF: Int?) {
        self.timers = timers
        self.temperatureF = temperatureF
    }

    public static let empty = StepTimerExtraction(timers: [], temperatureF: nil)

    /// Sane bounds, shared with the LLM mirror (ticket 4) and the confidence gate.
    public static let secondsRange = 5...(24 * 3600)
    public static let temperatureFRange = 100...700

    /// Deterministic extraction: first duration via `StepTimerParser`, temperature via
    /// `TemperatureConverter.fahrenheitValues(in:)` (take `.max()`, drop if out of range).
    public static func heuristic(from text: String) -> StepTimerExtraction {
        var timers: [StepTimer] = []
        if let duration = StepTimerParser.firstDuration(in: text) {
            let seconds = Int(duration.components.seconds)
            if secondsRange.contains(seconds) {
                timers.append(StepTimer(label: "Timer", seconds: seconds))
            }
        }
        let temp = TemperatureConverter.fahrenheitValues(in: text)
            .max()
            .flatMap { temperatureFRange.contains($0) ? $0 : nil }
        return StepTimerExtraction(timers: timers, temperatureF: temp)
    }
}

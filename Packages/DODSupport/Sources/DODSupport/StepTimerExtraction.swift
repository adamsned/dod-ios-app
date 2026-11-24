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

    /// Split a text into clauses using semicolons, commas followed by "then", "then", and periods followed by spaces.
    /// Returns non-empty pieces after trimming whitespace.
    static func clauses(of text: String) -> [String] {
        // Replace all separators with a single unique character to split on
        let separator = "\u{1}"
        var processedText = text.replacingOccurrences(of: ";", with: separator)
        processedText = processedText.replacingOccurrences(of: ", then ", with: separator)
        processedText = processedText.replacingOccurrences(of: "then ", with: separator)
        processedText = processedText.replacingOccurrences(of: ". ", with: separator)

        return processedText.components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Generate a label for a timer based on the clause and index.
    static func label(for clause: String, index: Int) -> String {
        let lowerClause = clause.lowercased()
        if lowerClause.contains("per side") || lowerClause.contains("each side") {
            return "Per side"
        } else if index == 0 {
            return "Timer"
        } else {
            return "Timer \(index + 1)"
        }
    }

    /// Deterministic extraction: first duration via `StepTimerParser`, temperature via
    /// `TemperatureConverter.fahrenheitValues(in:)` (take `.max()`, drop if out of range).
    public static func heuristic(from text: String) -> StepTimerExtraction {
        let clauses = clauses(of: text)

        var timers: [StepTimer] = []
        for (index, clause) in clauses.enumerated() {
            if let duration = StepTimerParser.firstDuration(in: clause) {
                let seconds = Int(duration.components.seconds)
                if secondsRange.contains(seconds) {
                    let label = label(for: clause, index: index)
                    timers.append(StepTimer(label: label, seconds: seconds))
                }
            }
        }

        // Cap at 2 timers as UI shows at most a second inline timer
        timers = Array(timers.prefix(2))

        let temp = TemperatureConverter.fahrenheitValues(in: text)
            .max()
            .flatMap { temperatureFRange.contains($0) ? $0 : nil }
        return StepTimerExtraction(timers: timers, temperatureF: temp)
    }
}

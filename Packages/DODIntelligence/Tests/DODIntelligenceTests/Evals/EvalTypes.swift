import Foundation

/// One input to an AI feature plus a human-readable label for failure output.
struct EvalCase<Input: Sendable>: Sendable {
    let name: String
    let input: Input
}

/// Result of grading one case. `failures` is empty when the case passed.
struct EvalOutcome: Sendable, Equatable {
    let caseName: String
    let failures: [String]
    var passed: Bool { failures.isEmpty }
}

/// Aggregate over many outcomes, with a pass-rate gate for non-deterministic paths.
struct EvalReport: Sendable {
    let outcomes: [EvalOutcome]

    var passRate: Double {
        guard !outcomes.isEmpty else { return 0 }
        return Double(outcomes.filter(\.passed).count) / Double(outcomes.count)
    }

    /// True when passRate >= threshold.
    func meets(threshold: Double) -> Bool { passRate >= threshold }

    /// One line per failing case, for use as an `#expect` comment.
    var failureSummary: String {
        outcomes.filter { !$0.passed }
            .map { "\($0.caseName): \($0.failures.joined(separator: "; "))" }
            .joined(separator: "\n")
    }
}

/// Runs `grade` over every case and collects the outcomes.
func runEval<Input: Sendable>(
    _ cases: [EvalCase<Input>],
    grade: (Input) async -> [String]
) async -> EvalReport {
    var outcomes: [EvalOutcome] = []
    for evalCase in cases {
        outcomes.append(EvalOutcome(caseName: evalCase.name, failures: await grade(evalCase.input)))
    }
    return EvalReport(outcomes: outcomes)
}

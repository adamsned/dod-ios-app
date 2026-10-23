import DODIntelligence
import Foundation
import Observation

/// DUT-1021 — drives the "Explain this step" card in Cook Mode.
@MainActor
@Observable
public final class StepExplainer {
    public enum State: Equatable {
        case idle
        case loading
        case loaded(StepExplanation)
        case unavailable
    }

    public private(set) var state: State = .idle
    private let intelligence: (any DODIntelligenceService)?
    private var cache: [Int: StepExplanation] = [:]

    public init(intelligence: (any DODIntelligenceService)?) {
        self.intelligence = intelligence
    }

    /// Hide the button entirely when there is no usable model (no dead control).
    public var isOffered: Bool { intelligence?.isAvailable ?? false }

    /// Explain `steps[index]`, passing the next step for continuity. Cached per step index.
    public func explain(steps: [String], index: Int) async {
        guard let intelligence, intelligence.isAvailable, steps.indices.contains(index) else {
            state = .unavailable
            return
        }
        if let cached = cache[index] {
            state = .loaded(cached)
            return
        }
        state = .loading
        let next = steps.indices.contains(index + 1) ? steps[index + 1] : nil
        if let result = await intelligence.explainStep(steps[index], nextStep: next) {
            cache[index] = result
            state = .loaded(result)
        } else {
            state = .unavailable
        }
    }

    /// Call when the cook moves to another step.
    public func reset() { state = .idle }
}

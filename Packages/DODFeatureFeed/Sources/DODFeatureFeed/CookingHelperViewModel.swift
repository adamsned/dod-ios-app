import DODIntelligence
import Foundation

/// T-934 (US-54 / AC-54.4) — the view model behind the Cooking Tools "Ask
/// Dutch Oven Daddy" helper: an on-device Q&A surface for cast-iron,
/// Dutch-oven, and technique questions.
///
/// This mirrors the Shopping List substitution seam (`#735`) exactly. It stores
/// the shared ``DODIntelligenceService`` PROTOCOL (never FoundationModels),
/// exposes ``isAvailable`` so the hub can hide the whole entry when no on-device
/// model can run, and drives an ``AnswerState`` machine so the sheet renders a
/// loading spinner, the answer in an elevated card, or a graceful "no answer
/// available" when the service returns `nil` (unavailable / empty / model error
/// / guardrail rejection — the service never throws).
@MainActor
@Observable
public final class CookingHelperViewModel {

    /// The on-device AI seam. `nil` when no service is wired (previews / tests
    /// that omit it) — then ``isAvailable`` is `false` and the helper stays
    /// hidden. Depends only on the protocol so DODFeatureFeed never imports
    /// FoundationModels.
    private let intelligence: (any DODIntelligenceService)?

    /// The answer surface's state machine, observed so the sheet reacts.
    public enum AnswerState: Equatable, Sendable {
        case idle
        case loading
        case loaded(String)
        case notFound
    }

    /// The current question text, bound to the sheet's text field.
    public var question: String = ""

    /// Current state of the answer surface. `internal(set)` so only ``ask()``
    /// and ``reset()`` mutate it while the view observes it.
    public internal(set) var answer: AnswerState = .idle

    /// - Parameter intelligence: The on-device AI seam backing the helper. Pass
    ///   `nil` (or an unavailable service) to model an unsupported device — the
    ///   hub then omits the helper entry entirely.
    public init(intelligence: (any DODIntelligenceService)?) {
        self.intelligence = intelligence
    }

    /// `true` only when an on-device model is usable right now. The hub renders
    /// the "Ask Dutch Oven Daddy" entry ONLY when this is `true`, so unsupported
    /// devices (iOS 17-25, incapable hardware, no Apple Intelligence) never see
    /// a dead control.
    public var isAvailable: Bool {
        intelligence?.isAvailable ?? false
    }

    /// Ask the on-device model the current ``question``, driving ``answer``
    /// through `.loading` → `.loaded` / `.notFound`. No-op when no model is
    /// available or the question is blank, so a spurious call can't open an
    /// empty result. A `nil` service result becomes the graceful `.notFound`.
    public func ask() async {
        guard let intelligence, intelligence.isAvailable else { return }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        answer = .loading
        let result = await intelligence.answer(trimmed)
        // Guard against a stale completion: if the user reset or asked a
        // different question while this awaited, don't clobber the newer state.
        guard answer == .loading else { return }
        if let result, !result.isEmpty {
            answer = .loaded(result)
        } else {
            answer = .notFound
        }
    }

    /// Return the answer surface to `.idle` (e.g. when the sheet is dismissed).
    public func reset() {
        answer = .idle
    }
}

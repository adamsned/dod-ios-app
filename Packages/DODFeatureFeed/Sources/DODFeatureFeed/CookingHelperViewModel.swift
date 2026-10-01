import DODIntelligence
import Foundation

/// T-934 (US-54 / DUT-1382) — the view model behind the "Ask Dutch Oven Daddy"
/// helper: an on-device, ChatGPT-style Q&A surface for any cooking or kitchen
/// question, optionally grounded in a photo the cook attaches.
///
/// It stores the shared ``DODIntelligenceService`` PROTOCOL (never
/// FoundationModels), exposes ``isAvailable`` so the hub can hide the whole
/// entry when no on-device model can run, and ``supportsImageInput`` so the
/// photo affordance only shows where the model can actually see images. Each
/// ask appends a user ``Turn`` and an assistant ``Turn`` to ``turns`` so the
/// sheet renders a scrolling conversation.
@MainActor
@Observable
public final class CookingHelperViewModel {

    /// The on-device AI seam. `nil` when no service is wired (previews / tests
    /// that omit it) — then ``isAvailable`` is `false` and the helper stays
    /// hidden. Depends only on the protocol so DODFeatureFeed never imports
    /// FoundationModels.
    private let intelligence: (any DODIntelligenceService)?

    /// One line in the conversation transcript.
    public struct Turn: Identifiable, Equatable, Sendable {
        public enum Role: Sendable { case user, assistant }
        public let id: UUID
        public let role: Role
        public let text: String
        /// For a user turn: whether the cook attached a photo (so the bubble can
        /// show a camera marker). Always `false` for assistant turns.
        public let hasImage: Bool
        /// For an assistant turn: `true` when the model returned nothing, so the
        /// bubble can render the graceful "no answer" styling.
        public let isEmptyResult: Bool

        public init(id: UUID = UUID(), role: Role, text: String, hasImage: Bool = false, isEmptyResult: Bool = false) {
            self.id = id
            self.role = role
            self.text = text
            self.hasImage = hasImage
            self.isEmptyResult = isEmptyResult
        }
    }

    /// The current draft question, bound to the input field.
    public var question: String = ""

    /// The conversation so far, oldest first. `internal(set)` so only ``ask`` /
    /// ``reset`` mutate it while the view observes it.
    public internal(set) var turns: [Turn] = []

    /// `true` while an answer is in flight (drives the "Thinking" row + disables
    /// send). `internal(set)` for the same reason.
    public internal(set) var isResponding = false

    public init(intelligence: (any DODIntelligenceService)?) {
        self.intelligence = intelligence
    }

    /// `true` only when an on-device model is usable right now. The hub renders
    /// the "Ask Dutch Oven Daddy" entry ONLY when this is `true`, so unsupported
    /// devices never see a dead control.
    public var isAvailable: Bool {
        intelligence?.isAvailable ?? false
    }

    /// `true` when the model can also take a photo as input (iOS 27+ capable
    /// device). The sheet shows the photo-attach button ONLY when this is `true`.
    public var supportsImageInput: Bool {
        intelligence?.supportsImageInput ?? false
    }

    /// Ask the model the current ``question`` plus an optional attached photo
    /// (`imageData`, JPEG/PNG bytes). Appends the user turn, clears the draft,
    /// runs the model, then appends the assistant turn. No-op when unavailable or
    /// when there is neither text nor an image. A `nil`/empty service result
    /// becomes a graceful empty-result assistant turn.
    public func ask(imageData: Data?) async {
        guard let intelligence, intelligence.isAvailable, !isResponding else { return }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || imageData != nil else { return }

        turns.append(Turn(role: .user, text: trimmed, hasImage: imageData != nil))
        question = ""
        isResponding = true

        let result = await intelligence.answer(trimmed, imageData: imageData)

        isResponding = false
        if let result, !result.isEmpty {
            turns.append(Turn(role: .assistant, text: result))
        } else {
            turns.append(
                Turn(
                    role: .assistant,
                    text: "I couldn't answer that one. Try rewording it, or attach a clearer photo.",
                    isEmptyResult: true
                )
            )
        }
    }

    /// Clear the conversation and draft (e.g. when the sheet is dismissed).
    public func reset() {
        turns = []
        question = ""
        isResponding = false
    }
}

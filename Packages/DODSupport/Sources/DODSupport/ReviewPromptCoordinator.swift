import Foundation

/// DUT-157 — glue between engagement signals, the policy, and the system review request.
@MainActor
public final class ReviewPromptCoordinator {
    public enum Signal: Sendable { case eligible, shown }
    private let store: ReviewPromptStore
    private let requestReview: @MainActor () -> Void
    private let report: @MainActor (Signal) -> Void
    private let now: () -> Date

    public init(
        store: ReviewPromptStore = ReviewPromptStore(),
        requestReview: @escaping @MainActor () -> Void,
        report: @escaping @MainActor (Signal) -> Void = { _ in },
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.requestReview = requestReview
        self.report = report
        self.now = now
    }

    public func recordSession() { store.recordSession() }
    public func recordRecipeView() { store.recordRecipeView() }

    /// User explicitly declined; suppress all future automatic prompts.
    public func markDeclined() { store.declined = true }
}

import DODSupport
import Foundation
import Observation

/// Process-wide message bus between AppIntents (which run outside any
/// SwiftUI view tree) and `RootView` (which owns tab + path state).
///
/// Spec trace: US-10 / AC-10.2. The intents call `dispatch(_:)`, the root
/// view observes `pending` via the Observation framework and routes
/// accordingly. Cleared by the consumer once routing has completed.
///
/// Singleton because there is exactly one root view per process and the
/// intent layer has no other handle. Marked `@Observable` so SwiftUI's
/// observation machinery picks up changes automatically.
@MainActor
@Observable
final class DeepLinkDispatcher {

    static let shared = DeepLinkDispatcher()

    /// The most recent intent that hasn't been routed yet. Routing code
    /// is responsible for setting this back to nil once it has taken
    /// effect; that ensures the same intent doesn't replay if the user
    /// rotates the device or otherwise causes a re-render.
    private(set) var pending: DeepLinkIntent?

    private init() {}

    /// Called from `AppIntent.perform()`. Calls are coalesced — if a new
    /// intent arrives before the previous one is consumed, the newer one
    /// wins (Siri only ever fires one intent at a time, but a user mashing
    /// Shortcuts could theoretically arrive faster than the route).
    nonisolated func dispatch(_ intent: DeepLinkIntent) {
        Task { @MainActor in
            self.pending = intent
        }
    }

    /// Routing path calls this once it has taken effect.
    func consume() {
        pending = nil
    }
}

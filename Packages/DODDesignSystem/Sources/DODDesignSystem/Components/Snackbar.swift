import SwiftUI

/// Auto-dismissing bottom snackbar. Optional Undo button on the trailing edge.
/// Default dismiss time is 4 seconds.
///
/// Used for save/unsave undo (AC-5.1) and "Recipe unavailable" (AC-4.11).
public struct Snackbar: View {

    public struct Action {
        public let title: String
        public let handler: @MainActor () -> Void
        public init(title: String, handler: @MainActor @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    public let message: String
    public let action: Action?

    /// DUT-230 — optional self-owned auto-dismiss. When supplied, the snackbar
    /// starts a countdown of ``autoDismissDelay`` and calls this once it
    /// elapses. The countdown is keyed to `message`, so a message-to-message
    /// replacement (a new non-nil message replacing the current one, with no
    /// intervening nil) **restarts** the countdown — the new message always
    /// gets its full duration rather than inheriting the previous message's
    /// remaining time. `nil` (the default) keeps the component a dumb leaf: a
    /// host that drives its own dismiss timer is unaffected.
    public let onAutoDismiss: (@MainActor () -> Void)?

    /// DUT-230 — how long a non-nil message stays up before ``onAutoDismiss``
    /// fires. Ignored when `onAutoDismiss` is `nil`.
    public let autoDismissDelay: Duration

    /// DUT-230 — the wait primitive the auto-dismiss countdown uses. Defaults
    /// to `Task.sleep`; tests inject a fake that resumes on demand so the
    /// restart-on-replacement behavior is asserted without a real sleep.
    private let sleep: @Sendable (Duration) async throws -> Void

    /// Bumped once on appear so `.sensoryFeedback` fires a subtle light tap
    /// for every fresh snackbar presentation, even if the message text is
    /// identical to a previously shown one.
    @State private var appearanceTrigger: Int = 0

    public init(message: String, action: Action? = nil) {
        self.init(message: message, action: action, onAutoDismiss: nil)
    }

    /// DUT-230 — designated initializer that opts the snackbar into owning its
    /// auto-dismiss countdown. `sleep` is a seam for tests; production callers
    /// leave it at the `Task.sleep` default.
    public init(
        message: String,
        action: Action? = nil,
        autoDismissDelay: Duration = .seconds(4),
        onAutoDismiss: (@MainActor () -> Void)?,
        sleep: @Sendable @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.message = message
        self.action = action
        self.autoDismissDelay = autoDismissDelay
        self.onAutoDismiss = onAutoDismiss
        self.sleep = sleep
    }

    public var body: some View {
        HStack(spacing: DODSpacing.md) {
            Text(message)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.cream)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let action {
                Button(action.title, action: action.handler)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.warmGold)
            }
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.castIronBrown)
        )
        .padding(.horizontal, DODSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(action.map { "\(message). \($0.title) available." } ?? message)
        .sensoryFeedback(.impact(weight: .light), trigger: appearanceTrigger)
        .onAppear {
            appearanceTrigger &+= 1
            // DUT-527 — the snackbar auto-dismisses in a few seconds, so a
            // VoiceOver user who isn't focused on it would never hear it.
            // Announce the message (and any action) once on appear.
            let spoken = action.map { "\(message). \($0.title) available." } ?? message
            AccessibilityNotification.Announcement(spoken).post()
        }
        // DUT-230 — key the auto-dismiss countdown to `message`. `.task(id:)`
        // cancels + re-runs whenever `message` changes, so a message-to-message
        // replacement restarts the full countdown instead of letting the new
        // message inherit the previous one's remaining time. No-op when the
        // host owns dismissal (`onAutoDismiss == nil`).
        .task(id: message) {
            await Self.runAutoDismiss(
                delay: autoDismissDelay,
                sleep: sleep,
                onAutoDismiss: onAutoDismiss
            )
        }
    }

    /// DUT-230 — the auto-dismiss countdown, factored out so it is exercised
    /// directly by tests with an injected `sleep` (no real wait, no SwiftUI
    /// render). Waits `delay` via `sleep`, then fires `onAutoDismiss`. If the
    /// wait is cancelled — which `.task(id:)` does on a message replacement or
    /// when the view goes away — it returns without firing, so the replaced
    /// message's countdown never dismisses the new one and each fresh call
    /// starts a clean full-duration countdown.
    @MainActor
    static func runAutoDismiss(
        delay: Duration,
        sleep: @Sendable (Duration) async throws -> Void,
        onAutoDismiss: (@MainActor () -> Void)?
    ) async {
        guard let onAutoDismiss else { return }
        do {
            try await sleep(delay)
        } catch {
            return  // cancelled (message replaced or view gone) — don't fire.
        }
        onAutoDismiss()
    }
}

#Preview("Plain") {
    Snackbar(message: "Recipe unavailable.")
}

#Preview("With Undo") {
    Snackbar(message: "Removed from saved.", action: .init(title: "Undo") {})
}

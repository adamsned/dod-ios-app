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
    /// elapses. The countdown is keyed to ``presentationToken`` (see below), so
    /// re-presenting **restarts** the countdown — the new presentation always
    /// gets its full duration rather than inheriting the previous one's
    /// remaining time. `nil` (the default) keeps the component a dumb leaf: a
    /// host that drives its own dismiss timer is unaffected.
    public let onAutoDismiss: (@MainActor () -> Void)?

    /// DUT-659 — the auto-dismiss countdown key. `.task(id:)` cancels + re-runs
    /// the countdown whenever this value changes. Keying on the message text
    /// (the old behavior) meant that replacing a message with an **identical**
    /// string never restarted the countdown, so a re-shown identical message
    /// inherited the previous one's remaining time (and could dismiss almost
    /// instantly). Hosts that re-present a snackbar should bump this token on
    /// each present (a monotonic counter) so every presentation — even one with
    /// the same text — gets a fresh full-duration countdown. Defaults to `0`;
    /// combined with `message` for the `.task` id so single-shot hosts that
    /// leave it at the default still restart on a genuine text change.
    public let presentationToken: Int

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
    /// leave it at the `Task.sleep` default. DUT-659 — `presentationToken`
    /// keys the countdown; bump it on each present so identical-text
    /// re-presentations restart the full countdown.
    public init(
        message: String,
        action: Action? = nil,
        autoDismissDelay: Duration = .seconds(4),
        presentationToken: Int = 0,
        onAutoDismiss: (@MainActor () -> Void)?,
        sleep: @Sendable @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.message = message
        self.action = action
        self.autoDismissDelay = autoDismissDelay
        self.presentationToken = presentationToken
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
        // DUT-659 — key the auto-dismiss countdown to a per-presentation token
        // (plus `message`), NOT the message text alone. `.task(id:)` cancels +
        // re-runs only when the id changes; keying on `message` alone meant an
        // identical-string replacement never restarted the countdown, so the
        // re-shown message inherited the previous one's remaining time. A host
        // that bumps `presentationToken` on every present now restarts the full
        // countdown even when the new message text is identical. No-op when the
        // host owns dismissal (`onAutoDismiss == nil`).
        .task(id: DismissKey(token: presentationToken, message: message)) {
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

    /// DUT-659 — the `.task(id:)` key for the auto-dismiss countdown. Combines
    /// the host-bumped `presentationToken` with `message` so the countdown
    /// restarts on either a genuine text change OR an identical-text
    /// re-presentation (token bump). Equal keys keep the in-flight countdown;
    /// any change cancels + restarts it.
    struct DismissKey: Equatable {
        let token: Int
        let message: String
    }
}

#Preview("Plain") {
    Snackbar(message: "Recipe unavailable.")
}

#Preview("With Undo") {
    Snackbar(message: "Removed from saved.", action: .init(title: "Undo") {})
}

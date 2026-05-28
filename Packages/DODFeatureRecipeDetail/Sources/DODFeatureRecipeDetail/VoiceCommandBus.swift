import Foundation
import Observation

/// The closed set of hands-free commands the Voice Mode Siri intents (US-40 /
/// T-690c) can drive against an active Cook Mode session.
///
/// Spec trace: US-40 / AC-40.5. Each case maps 1:1 to a ``VoiceCommandHandler``
/// method so the bus is a pure dispatch table with no behaviour of its own.
public enum VoiceCommand: Sendable, Hashable {
    case next
    case previous
    case `repeat`
    case pause
}

/// The surface a ``VoiceCommandBus`` forwards commands to. ``CookModeViewModel``
/// is the only production conformer; tests register a fake.
///
/// The four methods are exactly the AC-40.5 control surface T-690b wired to
/// `VoiceReader` — the bus is a thin adapter so a Siri command and an
/// on-screen tap reach identical code (AC-7.4).
@MainActor
public protocol VoiceCommandHandler: AnyObject {
    func advanceStep()
    func previousStep()
    func repeatCurrentStep()
    func pauseVoice()
}

/// Process-wide message bus between the Voice Mode `AppIntent`s (which run
/// outside any SwiftUI view tree, with no handle to the `@State`-owned Cook
/// Mode view model) and the **live** Cook Mode session.
///
/// Spec trace: US-40 / AC-40.5, CL-82. Mirrors the US-10 ``DeepLinkDispatcher``
/// pattern, but where the deep-link bus holds a *pending value* the root view
/// drains on the next render, this bus holds a **weak handler** the active
/// session registers itself as. Voice commands are imperative and only
/// meaningful while Cook Mode is foreground — there is no "consume later"
/// semantics — so a torn-down session is automatically a no-op (the handler is
/// `nil`) and Siri firing "next step" with no active session does nothing
/// rather than replaying into a stale view model.
///
/// Singleton because the intent layer has no other handle and there is at most
/// one foreground Cook Mode session per process. `@Observable` for symmetry
/// with ``DeepLinkDispatcher``; no view observes `handler` today.
@MainActor
@Observable
public final class VoiceCommandBus {

    public static let shared = VoiceCommandBus()

    /// The active Cook Mode session, or `nil` when Cook Mode isn't foreground.
    /// **Weak** so a dismissed `CookModeView` deallocates its view model even
    /// if `endCookMode()` somehow didn't run — the bus never keeps a dead
    /// session alive.
    public weak var handler: (any VoiceCommandHandler)?

    private init() {}

    /// Called from `AppIntent.perform()`. Hops to the main actor (the intent
    /// may run off it) and forwards to the registered handler, exactly like
    /// ``DeepLinkDispatcher/dispatch(_:)``. A no-op when no session is
    /// registered.
    nonisolated public func dispatch(_ command: VoiceCommand) {
        Task { @MainActor in
            self.deliver(command)
        }
    }

    /// Synchronous delivery seam — exercised directly by L1 tests so the
    /// dispatch table is asserted without an async hop.
    func deliver(_ command: VoiceCommand) {
        guard let handler else { return }
        switch command {
        case .next: handler.advanceStep()
        case .previous: handler.previousStep()
        case .repeat: handler.repeatCurrentStep()
        case .pause: handler.pauseVoice()
        }
    }
}

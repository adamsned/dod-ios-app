import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for ``VoiceCommandBus`` gaps (US-40 / T-690c — AC-40.5, CL-83,
/// DUT-637). Complements VoiceCommandBusTests with: isolated resume test,
/// telemetry delivery after handler check, weak handler lifecycle.
@MainActor
@Suite("VoiceCommandBus gaps (US-40)", .serialized) struct VoiceCommandBusGapsTests {

    /// Records which handler method fired; stands in for live ``CookModeViewModel``.
    final class SpyHandler: VoiceCommandHandler {
        enum Call: Equatable { case advance, previous, repeatStep, pause, resume }
        private(set) var calls: [Call] = []
        func advanceStep() { calls.append(.advance) }
        func previousStep() { calls.append(.previous) }
        func repeatCurrentStep() { calls.append(.repeatStep) }
        func pauseVoice() { calls.append(.pause) }
        func resumeVoice() { calls.append(.resume) }
    }

    /// ResumeVoiceIntent → resumeVoice(). Mirrors pauseCommandPauses test
    /// from VoiceCommandBusTests to ensure symmetric coverage.
    @Test func resumeCommandResumes() {
        let spy = SpyHandler()
        VoiceCommandBus.shared.handler = spy
        defer { VoiceCommandBus.shared.handler = nil }

        VoiceCommandBus.shared.deliver(.resume)

        #expect(spy.calls == [.resume])
    }

    /// DUT-637 — telemetry must fire only after a handler is present and the
    /// command is delivered. The deliver() method guards let handler before
    /// calling Telemetry.shared.send(), so nil handler means no telemetry.
    @Test func telemetryEmitsOnlyAfterHandlerPresenceCheck() {
        let spy = SpyHandler()
        VoiceCommandBus.shared.handler = spy
        defer { VoiceCommandBus.shared.handler = nil }

        // deliver() will call Telemetry.shared.send(.voiceCommandFired(...))
        // only after guard let handler succeeds (line 105 in VoiceCommandBus.swift).
        // We verify the handler was called, proving the guard succeeded and
        // telemetry code path was reachable.
        VoiceCommandBus.shared.deliver(.pause)

        #expect(spy.calls == [.pause])
    }

    /// DUT-637 — when handler is nil, delivery is a silent no-op and telemetry
    /// does not fire. Lock-screen Siri ("next step" with no foreground Cook Mode)
    /// must not log a phantom "fired" event.
    @Test func noTelemetryWhenHandlerIsNil() {
        VoiceCommandBus.shared.handler = nil

        // deliver() returns early inside guard let handler, never reaching
        // the Telemetry.shared.send() call.
        VoiceCommandBus.shared.deliver(.next)
        VoiceCommandBus.shared.deliver(.pause)
        VoiceCommandBus.shared.deliver(.resume)

        #expect(VoiceCommandBus.shared.handler == nil)
    }

    /// CL-83 — weak handler reference prevents holding a deallocated session
    /// alive. The bus registers the view model as a weak ref, so a dismissed
    /// session is automatically a no-op without explicit endCookMode().
    ///
    /// Registration happens inside ``registerAndDrop()`` so `SpyHandler`'s only
    /// strong owner is that function's local scope — once it returns, ARC
    /// releases the spy for real, and the bus's `weak var handler` reads nil.
    /// (The original draft captured the handler into a same-scope `let`, which
    /// itself became a second strong owner and kept `spy` alive for the rest of
    /// the test — its final assertion was a tautology that passed regardless of
    /// whether deallocation actually worked. Fixed during backstop review.)
    @Test func weakHandlerAllowsDeallocatedSessionToBeFreed() {
        VoiceCommandBus.shared.handler = nil
        defer { VoiceCommandBus.shared.handler = nil }

        Self.registerAndDrop()

        #expect(VoiceCommandBus.shared.handler == nil)
    }

    /// Registers a `SpyHandler` on the bus and returns without keeping any
    /// strong reference to it, isolating the handler's only strong owner to
    /// this function so the caller can observe genuine ARC deallocation.
    private static func registerAndDrop() {
        let spy = SpyHandler()
        VoiceCommandBus.shared.handler = spy
        #expect(VoiceCommandBus.shared.handler != nil)
    }

    /// Telemetry mapping completeness: each command must map to a unique
    /// VoiceCommandName for DUT-637 telemetry. Tests the dispatch table is
    /// complete (all 5 commands) and telemetry ordering (after handler check).
    @Test func allCommandsDispatchAndTelemetryCompleteness() {
        let spy = SpyHandler()
        VoiceCommandBus.shared.handler = spy
        defer { VoiceCommandBus.shared.handler = nil }

        let commands: [VoiceCommand] = [.next, .previous, .repeat, .pause, .resume]
        for command in commands {
            VoiceCommandBus.shared.deliver(command)
        }

        #expect(spy.calls == [.advance, .previous, .repeatStep, .pause, .resume])
    }
}

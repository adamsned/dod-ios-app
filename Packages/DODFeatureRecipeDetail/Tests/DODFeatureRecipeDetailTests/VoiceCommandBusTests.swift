import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the Voice Mode Siri-intent dispatch layer (US-40 / T-690c —
/// AC-40.5, CL-82). The four `AppIntent`s in the App target are thin adapters
/// that call `VoiceCommandBus.shared.dispatch(_:)`; this suite asserts the bus
/// forwards each command to the right ``VoiceCommandHandler`` method and that
/// the weak-handler lifecycle (register on begin, clear on end) makes a
/// torn-down session a no-op — the behaviour the intents rely on.
@MainActor
@Suite("VoiceCommandBus dispatch (US-40)") struct VoiceCommandBusTests {

    /// Records which handler method fired so each command can be asserted in
    /// isolation. Stands in for the live `CookModeViewModel`.
    final class SpyHandler: VoiceCommandHandler {
        enum Call: Equatable { case advance, previous, repeatStep, pause }
        private(set) var calls: [Call] = []
        func advanceStep() { calls.append(.advance) }
        func previousStep() { calls.append(.previous) }
        func repeatCurrentStep() { calls.append(.repeatStep) }
        func pauseVoice() { calls.append(.pause) }
    }

    /// Each command maps to exactly one handler method (AC-40.5). Uses the
    /// synchronous `deliver(_:)` seam so the dispatch table is asserted without
    /// an async hop; `dispatch(_:)` is the same path with a `@MainActor` Task.
    @Test func eachCommandForwardsToTheMatchingMethod() {
        let bus = VoiceCommandBus.shared
        let spy = SpyHandler()
        bus.handler = spy
        defer { bus.handler = nil }

        bus.deliver(.next)
        bus.deliver(.previous)
        bus.deliver(.repeat)
        bus.deliver(.pause)

        #expect(spy.calls == [.advance, .previous, .repeatStep, .pause])
    }

    /// NextStepIntent → advanceStep().
    @Test func nextCommandAdvances() {
        let spy = SpyHandler()
        VoiceCommandBus.shared.handler = spy
        defer { VoiceCommandBus.shared.handler = nil }

        VoiceCommandBus.shared.deliver(.next)

        #expect(spy.calls == [.advance])
    }

    /// PreviousStepIntent → previousStep().
    @Test func previousCommandStepsBack() {
        let spy = SpyHandler()
        VoiceCommandBus.shared.handler = spy
        defer { VoiceCommandBus.shared.handler = nil }

        VoiceCommandBus.shared.deliver(.previous)

        #expect(spy.calls == [.previous])
    }

    /// RepeatStepIntent → repeatCurrentStep().
    @Test func repeatCommandRepeats() {
        let spy = SpyHandler()
        VoiceCommandBus.shared.handler = spy
        defer { VoiceCommandBus.shared.handler = nil }

        VoiceCommandBus.shared.deliver(.repeat)

        #expect(spy.calls == [.repeatStep])
    }

    /// PauseVoiceIntent → pauseVoice().
    @Test func pauseCommandPauses() {
        let spy = SpyHandler()
        VoiceCommandBus.shared.handler = spy
        defer { VoiceCommandBus.shared.handler = nil }

        VoiceCommandBus.shared.deliver(.pause)

        #expect(spy.calls == [.pause])
    }

    /// CL-82 — a command fired with no active Cook Mode session is a silent
    /// no-op (the weak handler is nil). This is the lock-screen-Siri case.
    @Test func commandWithNoHandlerIsANoOp() {
        VoiceCommandBus.shared.handler = nil

        // Must not crash / must not throw.
        VoiceCommandBus.shared.deliver(.next)
        VoiceCommandBus.shared.deliver(.pause)

        #expect(VoiceCommandBus.shared.handler == nil)
    }

    /// CL-82 — `beginCookMode()` registers the view model as the live handler
    /// and `endCookMode()` clears it, so the bus only ever drives the
    /// foreground session.
    @Test func cookModeLifecycleRegistersAndClearsHandler() {
        VoiceCommandBus.shared.handler = nil
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 3)

        viewModel.beginCookMode()
        #expect(VoiceCommandBus.shared.handler === viewModel)

        viewModel.endCookMode()
        #expect(VoiceCommandBus.shared.handler == nil)
    }

    /// A dispatched command after registration drives the real view model's
    /// navigation (end-to-end through the live handler, not just the spy).
    @Test func dispatchDrivesTheRegisteredViewModel() {
        VoiceCommandBus.shared.handler = nil
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 3)
        viewModel.beginCookMode()
        defer { viewModel.endCookMode() }

        VoiceCommandBus.shared.deliver(.next)

        #expect(viewModel.currentStepIndex == 1)
    }
}

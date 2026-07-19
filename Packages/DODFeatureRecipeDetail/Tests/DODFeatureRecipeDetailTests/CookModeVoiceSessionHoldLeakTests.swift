import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// Regression coverage for a DUT-390 sibling-path gap: ``VoiceReader``'s
/// "hold the session open across steps" flag (`holdsSessionOpen`, flipped by
/// ``VoiceReader/setSessionHold(_:)``) leaking across a Cook Mode session
/// boundary.
///
/// `CookModeViewModel.setVoiceMode(false)` explicitly drops the hold ("so any
/// later one-shot replay releases it on completion too" — see
/// `CookModeViewModel+Voice.swift`), but `endCookMode()` used to stop the
/// reader WITHOUT dropping the hold. If a cook exited Cook Mode while Voice
/// Mode was still on, `holdsSessionOpen` stayed latched `true` on the
/// `VoiceReader` even though the session itself was torn down. On re-entry —
/// `beginCookMode()`/`endCookMode()` are explicitly designed to run
/// repeatedly on the SAME view model instance, per this file's "a re-entry
/// starts clean" comments — a one-shot replay (``replayCurrentStep()``,
/// which works regardless of the Voice Mode toggle) would re-activate the
/// audio session, but its completion could never release it: the reader's
/// `onQueueDidEmpty` drain handler only deactivates when `!holdsSessionOpen`,
/// which stayed (wrongly) false to check — i.e. the guard kept returning
/// early. The result: other apps' audio stayed ducked for the rest of the new
/// session, with no toggle short of quitting the app able to clear it.
@MainActor
@Suite("CookModeViewModel Voice Mode session-hold leak (DUT-390)")
struct CookModeVoiceSessionHoldLeakTests {

    /// Exiting Cook Mode while Voice Mode was on must drop the reader's
    /// session hold, so a one-shot replay in a LATER Cook Mode session (Voice
    /// Mode off) still releases the ducked audio session when it finishes.
    @Test func endCookModeDropsTheSessionHoldSoALaterReplayReleasesTheDuckedSession() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 3, voiceReader: reader)

        // First Cook Mode session: turn Voice Mode on (holds the session open
        // across steps) then leave Cook Mode while it's still on.
        viewModel.beginCookMode()
        viewModel.setVoiceMode(true)
        #expect(reader.hasActiveAudioSession)

        viewModel.endCookMode()
        // `stop()` deactivates immediately regardless of the hold, so this
        // much already passed before the fix.
        #expect(!reader.hasActiveAudioSession)

        // Re-enter Cook Mode (same view model instance — a supported re-entry
        // per `beginCookMode()`'s idempotency guard). Voice Mode defaults back
        // off, but the reader's internal hold flag is what's under test here.
        viewModel.beginCookMode()
        #expect(!viewModel.isVoiceModeEnabled)

        // A one-shot replay while Voice Mode is off — activates the session.
        viewModel.replayCurrentStep()
        #expect(reader.hasActiveAudioSession)

        // The utterance finishes and the queue drains.
        mock.simulateQueueDrained()

        // The ducked session must be released once this one-shot read
        // finishes — a leaked hold from the PRIOR session must not keep
        // other apps' audio ducked into this one.
        #expect(!reader.hasActiveAudioSession)
    }
}

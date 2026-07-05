import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the DUT-583 Cook Mode player refinements on
/// ``CookModeViewModel``: the single play / pause / resume transport (which
/// pauses in place and resumes without restarting — and no longer double-speaks
/// on start), and the discrete speed control (cycle + exact-pick + labels).
///
/// Each test injects a real ``VoiceReader`` over a ``MockSpeechSynthesizer`` so
/// the speak / pause / continue sequence is asserted with zero real audio. The
/// shared `makeViewModel` helper produces step bodies `"Step 1 body."`, … .
@MainActor
@Suite("Cook Mode player transport + speed (DUT-583)")
struct CookModePlaybackTests {

    // MARK: - Transport (play / pause / resume)

    /// Play from idle enables Voice Mode and speaks the step EXACTLY once — the
    /// old "toggle then replay" double-speak is gone.
    @Test func playFromIdleSpeaksExactlyOnce() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        #expect(viewModel.playbackState == .idle)

        viewModel.togglePlayback()

        #expect(viewModel.isVoiceModeEnabled)
        #expect(viewModel.playbackState == .speaking)
        #expect(viewModel.isPlaying)
        #expect(mock.spokenTexts == ["Step 1 body."])
    }

    /// Pause holds the position (a real `pause`, not a stop) and resume
    /// continues from there (`continueSpeaking`, NOT a fresh `speak`) — so the
    /// step never replays from the beginning on resume.
    @Test func pauseThenResumeDoesNotRestart() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.togglePlayback()  // idle -> speaking (1 speak)
        viewModel.togglePlayback()  // speaking -> paused

        #expect(viewModel.playbackState == .paused)
        #expect(!viewModel.isPlaying)
        #expect(mock.calls.contains(.pause))

        viewModel.togglePlayback()  // paused -> speaking (resume)

        #expect(viewModel.playbackState == .speaking)
        #expect(mock.calls.contains(.continueSpeaking))
        // Exactly ONE speak across the whole play/pause/resume cycle.
        #expect(mock.spokenTexts == ["Step 1 body."])
    }

    /// DUT-595 — after an audio interruption ends WITHOUT `.shouldResume`, the
    /// reader leaves playback parked and fires `onDidPauseForInterruption`. The
    /// VM must drop the transport out of `.speaking` (so the glyph shows "play"
    /// and VoiceOver stops mis-reporting "playing") and a SINGLE tap must resume
    /// with a fresh read — not the old no-op `pauseVoice()` that took two taps.
    @Test func interruptionWithoutResumeSyncsTransportAndResumesInOneTap() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: reader
        )
        viewModel.togglePlayback()  // idle -> speaking (1 speak)
        #expect(viewModel.playbackState == .speaking)
        #expect(viewModel.isVoiceModeEnabled)

        // Simulate the reader's `.ended`-without-`shouldResume` branch (the
        // iOS-only interruption handler is compiled out on the macOS test slice).
        reader.onDidPauseForInterruption?()

        // Transport no longer claims to be playing while silent.
        #expect(viewModel.playbackState != .speaking)
        #expect(!viewModel.isPlaying)

        // A single tap resumes — one fresh read, no wasted no-op tap.
        viewModel.togglePlayback()

        #expect(viewModel.playbackState == .speaking)
        #expect(viewModel.isPlaying)
        #expect(mock.spokenTexts == ["Step 1 body.", "Step 1 body."])
    }

    /// DUT-595 — the interruption callback must not stomp a `.paused` state the
    /// user just set (a stale/late fire): it only fires the transport out of
    /// `.speaking`, mirroring the `onDidFinishSpeaking` `.speaking`-guard.
    @Test func interruptionCallbackDoesNotStompUserPause() {
        let mock = MockSpeechSynthesizer()
        let reader = VoiceReader(synthesizer: mock)
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: reader
        )
        viewModel.togglePlayback()  // speaking
        viewModel.togglePlayback()  // user paused
        #expect(viewModel.playbackState == .paused)

        reader.onDidPauseForInterruption?()

        #expect(viewModel.playbackState == .paused)
    }

    /// A one-shot replay while Voice Mode is OFF still reads once but leaves the
    /// transport idle (it is not a play/pause session).
    @Test func replayWhileVoiceOffLeavesTransportIdle() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.replayCurrentStep()

        #expect(viewModel.playbackState == .idle)
        #expect(!viewModel.isVoiceModeEnabled)
        #expect(mock.spokenTexts == ["Step 1 body."])
    }

    /// Exiting Cook Mode resets the transport to idle and the speed to 1×, so a
    /// re-entry starts clean.
    @Test func endCookModeResetsTransportAndSpeed() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.beginCookMode()
        viewModel.togglePlayback()  // speaking
        viewModel.cycleVoiceSpeed()  // 1.25x

        viewModel.endCookMode()

        #expect(viewModel.playbackState == .idle)
        #expect(viewModel.voiceSpeedMultiplier == 1.0)
    }

    // MARK: - Speed control

    /// Speed starts at the natural 1× and labels compactly.
    @Test func speedDefaultsToOneX() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        #expect(viewModel.voiceSpeedMultiplier == 1.0)
        #expect(viewModel.voiceSpeedLabel == "1x")
    }

    /// A tap cycles up through the speeds and wraps from the top (2×) back to the
    /// bottom (0.5×), then climbs back to 1×.
    @Test func cycleVoiceSpeedAdvancesThenWraps() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        let expected: [Double] = [1.25, 1.5, 1.75, 2.0, 0.5, 0.75, 1.0]
        var got: [Double] = []
        for _ in expected {
            viewModel.cycleVoiceSpeed()
            got.append(viewModel.voiceSpeedMultiplier)
        }
        #expect(got == expected)
    }

    /// The menu picks an exact speed; the label follows.
    @Test func setVoiceSpeedPicksExactValue() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        viewModel.setVoiceSpeed(1.75)
        #expect(viewModel.voiceSpeedMultiplier == 1.75)
        #expect(viewModel.voiceSpeedLabel == "1.75x")
    }

    /// Speed labels drop trailing zeros: whole numbers read "Nx".
    @Test func speedLabelsFormatCompactly() {
        #expect(CookModeViewModel.speedLabel(for: 0.5) == "0.5x")
        #expect(CookModeViewModel.speedLabel(for: 0.75) == "0.75x")
        #expect(CookModeViewModel.speedLabel(for: 1.0) == "1x")
        #expect(CookModeViewModel.speedLabel(for: 1.25) == "1.25x")
        #expect(CookModeViewModel.speedLabel(for: 1.5) == "1.5x")
        #expect(CookModeViewModel.speedLabel(for: 2.0) == "2x")
    }

    /// Changing speed while actively reading re-speaks the step at the new pace.
    @Test func changingSpeedWhileSpeakingRespeaks() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.togglePlayback()  // speaking, 1 speak

        viewModel.setVoiceSpeed(1.5)

        #expect(viewModel.playbackState == .speaking)
        #expect(mock.spokenTexts == ["Step 1 body.", "Step 1 body."])
    }

    /// Changing speed while PAUSED must not start playback — it only primes the
    /// next utterance, leaving the reader paused where it was.
    @Test func changingSpeedWhilePausedDoesNotResume() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.togglePlayback()  // speaking
        viewModel.togglePlayback()  // paused
        let speaksBefore = mock.spokenTexts.count

        viewModel.setVoiceSpeed(1.5)

        #expect(viewModel.playbackState == .paused)
        #expect(mock.spokenTexts.count == speaksBefore)
        #expect(viewModel.voiceSpeedLabel == "1.5x")
    }

    /// The multiplier→engine-rate mapping lines the extremes up exactly with the
    /// reader's clamped bounds (no clamping needed for the listed speeds).
    @Test func rateMappingMatchesReaderBounds() {
        #expect(VoiceReader.rate(for: 1.0) == VoiceReader.defaultRate)
        #expect(VoiceReader.rate(for: 2.0) == VoiceReader.maximumRate)
        #expect(VoiceReader.rate(for: 0.5) == VoiceReader.minimumRate)
    }
}

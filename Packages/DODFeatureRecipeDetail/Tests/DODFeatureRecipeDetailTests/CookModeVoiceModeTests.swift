import DODAnalytics
import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the in-app Voice Mode wiring on ``CookModeViewModel``
/// (US-40 / T-690b — AC-40.1 toggle, AC-40.3 re-read on step change, and the
/// AC-40.5 control surface the T-690c App Intents will call).
///
/// Each test injects a real ``VoiceReader`` driven by a ``MockSpeechSynthesizer``
/// (defined alongside ``VoiceReaderTests``) so the toggle / re-read / pause /
/// stop contract is asserted with zero real-audio dependency (CL-79 / CL-81).
/// The step bodies the shared `makeViewModel` helper produces are
/// `"Step 1 body."`, `"Step 2 body."`, … so the spoken-text assertions read
/// against those.
@MainActor
@Suite("CookModeViewModel Voice Mode (US-40)") struct CookModeVoiceModeTests {

    /// AC-40.1 — Voice Mode is off every time Cook Mode is entered.
    @Test func voiceModeIsOffByDefault() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 3)
        #expect(!viewModel.isVoiceModeEnabled)
    }

    /// AC-40.1 + AC-40.2 — toggling Voice Mode on immediately reads the
    /// current step aloud.
    @Test func turningVoiceModeOnSpeaksTheCurrentStep() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.setVoiceMode(true)

        #expect(viewModel.isVoiceModeEnabled)
        #expect(mock.spokenTexts == ["Step 1 body."])
    }

    /// AC-40.3 — advancing a step while Voice Mode is on re-reads the new step.
    @Test func stepChangeReReadsWhileVoiceModeOn() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)  // speaks step 1

        viewModel.advanceStep()  // -> step 2
        viewModel.previousStep()  // -> step 1

        #expect(mock.spokenTexts == ["Step 1 body.", "Step 2 body.", "Step 1 body."])
    }

    /// On-screen Next/Previous (which call goNext/goBack directly) re-read too —
    /// the re-read driver hangs off navigation, not just the voice-command
    /// wrappers (AC-40.3).
    @Test func onScreenNavigationAlsoReReads() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)

        viewModel.goNext()

        #expect(mock.spokenTexts == ["Step 1 body.", "Step 2 body."])
    }

    /// AC-40.3 — reaching the Done state speaks a completion line, not a step.
    /// DUT-325 — the non-dessert completion line is "All done, enjoy your meal"
    /// (no em dash). On-screen copy is unaffected (TTS only).
    @Test func reachingDoneSpeaksCompletionLine() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 1,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)  // speaks the single step

        viewModel.advanceStep()  // -> finished

        #expect(viewModel.isFinished)
        #expect(mock.spokenTexts.last == "All done, enjoy your meal")
    }

    /// DUT-325 — a dessert recipe (WP category 336) speaks the dessert-tailored
    /// completion line. Detection is via `recipe.categoryIDs.contains(336)`.
    @Test func reachingDoneSpeaksDessertLineForDesserts() {
        let mock = MockSpeechSynthesizer()
        let recipe = Recipe(
            id: 336_001,
            slug: "dessert",
            title: "Skillet Brownies",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/336001/") ?? URL(filePath: "/"),
            categoryIDs: [336],
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            instructions: [RecipeInstruction(step: 1, text: "Step 1 body.")]
        )
        let viewModel = CookModeViewModel(
            recipe: recipe,
            initialCheckedIngredients: [],
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)  // speaks the single step

        viewModel.advanceStep()  // -> finished

        #expect(viewModel.isFinished)
        #expect(mock.spokenTexts.last == "All done, enjoy your dessert")
    }

    /// DUT-325 — the replay button reads the current step ONE-SHOT even while
    /// Voice Mode is off (contrast `repeatCurrentStep`, which stays silent).
    @Test func replayCurrentStepSpeaksEvenWhileVoiceModeOff() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        #expect(!viewModel.isVoiceModeEnabled)

        viewModel.replayCurrentStep()

        #expect(mock.spokenTexts == ["Step 1 body."])
        #expect(!viewModel.isVoiceModeEnabled)  // replay does not flip the toggle
    }

    /// AC-40.5 — "repeat" re-speaks the same step without moving position.
    @Test func repeatReReadsTheSameStep() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)
        viewModel.advanceStep()  // -> step 2

        viewModel.repeatCurrentStep()

        #expect(viewModel.currentStepIndex == 1)
        #expect(mock.spokenTexts == ["Step 1 body.", "Step 2 body.", "Step 2 body."])
    }

    /// AC-40.4 / AC-40.5 — "pause" pauses the current utterance.
    @Test func pauseVoicePausesTheReader() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)

        viewModel.pauseVoice()

        #expect(mock.calls.contains(.pause))
        #expect(mock.isPaused)
    }

    /// DUT-343 — "resume" resumes a paused utterance, so "Pause" isn't a
    /// hands-free dead-end. Pairs with `pauseVoice()`.
    @Test func resumeVoiceResumesThePausedReader() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)
        viewModel.pauseVoice()
        #expect(mock.isPaused)

        viewModel.resumeVoice()

        #expect(mock.calls.contains(.continueSpeaking))
        #expect(mock.isSpeaking)
        #expect(!mock.isPaused)
    }

    /// DUT-620 — with Voice Mode off, a Siri "pause"/"resume" must not flip the
    /// transport state. Before the guard, `pauseVoice()`/`resumeVoice()`
    /// unconditionally set `playbackState`, spuriously showing paused/speaking.
    @Test func pauseAndResumeDoNotFlipTransportWhenVoiceModeOff() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        #expect(!viewModel.isVoiceModeEnabled)
        #expect(viewModel.playbackState == .idle)

        viewModel.pauseVoice()
        #expect(viewModel.playbackState == .idle)

        viewModel.resumeVoice()
        #expect(viewModel.playbackState == .idle)
    }

    /// AC-40.1 — toggling Voice Mode off stops the reader and disables the flag.
    @Test func turningVoiceModeOffStopsTheReader() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.setVoiceMode(true)
        #expect(mock.isSpeaking)

        viewModel.setVoiceMode(false)

        #expect(!viewModel.isVoiceModeEnabled)
        #expect(!mock.isSpeaking)
        #expect(mock.calls.last == .stop)
    }

    /// While Voice Mode is off, navigation must stay silent — no utterance the
    /// user didn't ask for.
    @Test func navigationIsSilentWhileVoiceModeOff() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.goNext()
        viewModel.advanceStep()
        viewModel.repeatCurrentStep()

        #expect(mock.calls.isEmpty)
    }

    /// AC-40.8 / CL-83 — flipping Voice Mode fires `voiceModeToggled(on:)` once
    /// per actual change, with the right boolean and no other payload. An
    /// idempotent re-set (same value) does not re-fire.
    @Test func togglingVoiceModeFiresAnalyticsOnFlipOnly() {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        defer { Telemetry.shared.replaceTransport(RecordingTelemetryTransport()) }

        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )

        viewModel.setVoiceMode(true)  // flip on -> fires on:true
        viewModel.setVoiceMode(true)  // idempotent re-read -> no event
        viewModel.setVoiceMode(false)  // flip off -> fires on:false

        let toggles = recorder.events.filter { $0.name == "voice_mode_toggled" }
        #expect(toggles.map(\.payload) == [["on": "true"], ["on": "false"]])
    }

    /// AC-7.6 — exiting Cook Mode stops the reader and clears Voice Mode.
    @Test func endCookModeStopsTheReader() {
        let mock = MockSpeechSynthesizer()
        let viewModel = CookModeViewModelTests.makeViewModel(
            stepCount: 3,
            voiceReader: VoiceReader(synthesizer: mock)
        )
        viewModel.beginCookMode()
        viewModel.setVoiceMode(true)
        #expect(mock.isSpeaking)

        viewModel.endCookMode()

        #expect(!viewModel.isVoiceModeEnabled)
        #expect(!mock.isSpeaking)
        #expect(mock.calls.last == .stop)
    }

    // MARK: - Voice upgrade prompt gate (DUT-328)

    private func upgradeViewModel(voices: [VoiceDescriptor]) -> CookModeViewModel {
        let mock = MockSpeechSynthesizer()
        mock.stubbedVoices = voices
        let recipe = Recipe(
            id: 1,
            slug: "r",
            title: "R",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/1/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            instructions: [RecipeInstruction(step: 1, text: "Step 1.")]
        )
        return CookModeViewModel(
            recipe: recipe,
            initialCheckedIngredients: [],
            voiceReader: VoiceReader(synthesizer: mock),
            locale: Locale(identifier: "en-US")
        )
    }

    @Test func offersUpgradeWhenOnlyRoboticVoiceInstalled() {
        let viewModel = upgradeViewModel(voices: [
            VoiceDescriptor(identifier: "compact", languageCode: "en-US", quality: .default)
        ])
        #expect(viewModel.shouldOfferVoiceUpgrade)
    }

    @Test func noUpgradeWhenANaturalVoiceIsInstalled() {
        // A natural voice of EITHER gender means the user is set — no prompt.
        let viewModel = upgradeViewModel(voices: [
            VoiceDescriptor(identifier: "compact", languageCode: "en-US", quality: .default),
            VoiceDescriptor(identifier: "enhanced", languageCode: "en-US", quality: .enhanced),
        ])
        #expect(!viewModel.shouldOfferVoiceUpgrade)
    }

    @Test func noUpgradeWhenCatalogIsUnknown() {
        // An empty catalog reads as "unknown" (e.g. the preview/host double) →
        // never a false prompt.
        let viewModel = upgradeViewModel(voices: [])
        #expect(!viewModel.shouldOfferVoiceUpgrade)
    }
}

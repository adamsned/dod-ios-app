import DODAnalytics
import DODSupport
import Foundation

/// Voice Mode (US-40) + voice pacing (DUT-325) surface for ``CookModeViewModel``.
///
/// Extracted from `CookModeViewModel.swift` so the core navigation/lifecycle
/// type body stays under the SwiftLint `type_body_length` cap. Everything here
/// drives the injected ``VoiceReader``:
/// - the on-screen toggle (AC-40.1) + immediate read (AC-40.2),
/// - the dessert-aware spoken completion line (DUT-325, no em dash),
/// - the one-shot replay button (DUT-325) that works regardless of the toggle,
/// - the session-only Slower/Faster pacing controls (DUT-325),
/// - the AC-40.5 voice-command surface the T-690c App Intents call.
extension CookModeViewModel {

    /// Flip Voice Mode on or off (AC-40.1). Turning it **on** immediately reads
    /// the current step (AC-40.2); turning it **off** stops reading and releases
    /// the audio session. Idempotent — setting the same value re-reads the
    /// current step (on) or is a no-op (off).
    public func setVoiceMode(_ enabled: Bool) {
        let changed = isVoiceModeEnabled != enabled
        isVoiceModeEnabled = enabled
        if enabled {
            // DUT-390 — hold the audio session open across steps while Voice
            // Mode is on so other audio doesn't un-duck/re-duck between reads.
            voiceReader.setSessionHold(true)
            speakCurrentStep()  // sets playbackState = .speaking
        } else {
            // DUT-390 — stop() releases the session now; drop the hold so any
            // later one-shot replay releases it on completion too.
            voiceReader.setSessionHold(false)
            voiceReader.stop()
            playbackState = .idle
        }
        // AC-40.8 / CL-83 — report the user-driven on/off as an allowlisted
        // device-state event. Payload is a single boolean — no recipe id, no
        // free text. Only fire on an actual flip so an idempotent re-set (which
        // re-reads the current step) doesn't double-count.
        if changed {
            Telemetry.shared.send(.voiceModeToggled(on: enabled))
        }
    }

    /// Convenience for the on-screen toggle button (AC-40.1).
    public func toggleVoiceMode() {
        setVoiceMode(!isVoiceModeEnabled)
    }

    /// DUT-328 — true when Voice Mode is on a **robotic** voice the user could
    /// upgrade: a real catalog is loaded AND no natural (enhanced/premium) voice
    /// is installed for the device language. An empty catalog reads as "unknown"
    /// → false (never a false prompt), mirroring the Settings download-nudge gate.
    /// Drives the one-time Cook Mode "get a better voice" prompt.
    public var shouldOfferVoiceUpgrade: Bool {
        let catalog = voiceReader.installedVoices()
        guard !catalog.isEmpty else { return false }
        return !VoiceSelector.hasNaturalVoice(forLanguage: voiceLanguageCode, in: catalog)
    }

    /// Re-speak the current step (or the completion line in the Done state).
    /// Drives AC-40.3's re-read-on-step-change behaviour and AC-40.5's
    /// "repeat" command. A no-op while Voice Mode is off so navigation never
    /// makes noise the user didn't ask for. Because ``VoiceReader/speak(_:)``
    /// stops any in-flight utterance first (AC-40.7), advancing several steps
    /// quickly never overlaps two voices.
    func speakCurrentStep() {
        guard isVoiceModeEnabled else { return }
        let text = currentSpokenText
        guard !text.isEmpty else { return }
        voiceReader.speak(text)
        playbackState = .speaking
    }

    /// DUT-583 — the single center play/pause control, podcast-style. Pauses
    /// speaking in place, resumes from where it left off, or starts reading
    /// when idle. This is the ONLY thing the on-screen button calls, so the
    /// "play then replay" double-speak (a play tap reading the step twice) is
    /// gone: starting simply enables Voice Mode, which reads once.
    public func togglePlayback() {
        switch playbackState {
        case .speaking:
            pauseVoice()
        case .paused:
            resumeVoice()
        case .idle:
            if isVoiceModeEnabled {
                // Voice Mode is on but the step finished reading — read it again.
                speakCurrentStep()
            } else {
                setVoiceMode(true)  // enable + read once
            }
        }
    }

    /// DUT-583 — true while a step is actively being read (the center button
    /// shows a pause glyph); false when idle or paused (shows play).
    public var isPlaying: Bool {
        playbackState == .speaking
    }

    /// DUT-325 — the text Voice Mode reads for the current position: the step
    /// body, or a dessert-aware completion line in the Done state. Shared by
    /// the auto-read path (``speakCurrentStep()``) and the one-shot replay
    /// (``replayCurrentStep()``) so both stay in lock-step.
    private var currentSpokenText: String {
        if isFinished {
            // AC-40.3 — reaching Done speaks a short completion line rather
            // than a step body. DUT-325 — tailor "meal" vs "dessert" and drop
            // the em dash. On-screen copy is unaffected (TTS only).
            return isDessert ? "All done, enjoy your dessert" : "All done, enjoy your meal"
        }
        let text = currentStep?.text ?? ""
        // DUT-245 — read the current step in the user's chosen temperature unit
        // so the voice matches the on-screen text (which Cook Mode + Recipe
        // Detail both convert). `nil` preference leaves the text untouched.
        let rawUnit = UserDefaults.standard.string(forKey: TemperatureConverter.preferenceKey)
        guard let unit = TemperatureConverter.resolvedUnit(fromRawValue: rawUnit) else {
            return text
        }
        return TemperatureConverter.converting(text, to: unit)
    }

    /// DUT-325 — true when this recipe is filed under the "Dessert Recipes" WP
    /// category (id 336), used to tailor the spoken completion line.
    private var isDessert: Bool {
        recipe.categoryIDs.contains(336)
    }

    /// DUT-325 — speak the current step (or the Done line) exactly once,
    /// **independently of the Voice Mode toggle**. Drives the on-screen replay
    /// button so a user who hasn't enabled hands-free reading can still tap to
    /// hear the step. Contrast ``repeatCurrentStep()``, which is the AC-40.5
    /// voice command and stays silent while Voice Mode is off.
    public func replayCurrentStep() {
        let text = currentSpokenText
        guard !text.isEmpty else { return }
        voiceReader.speak(text)
        // A replay while Voice Mode is on restarts the read, so reflect that in
        // the transport; a one-shot replay with Voice Mode off is transient and
        // leaves the (idle) player button alone.
        if isVoiceModeEnabled { playbackState = .speaking }
    }

    // MARK: - Voice pacing (DUT-325 / DUT-583)

    /// DUT-583 — the current speed as a display label for the speed button:
    /// "1x", "1.5x", "0.5x", etc. (trailing zeros trimmed).
    public var voiceSpeedLabel: String {
        Self.speedLabel(for: voiceSpeedMultiplier)
    }

    /// DUT-583 — format any speed multiplier as a compact label ("1x", "1.5x",
    /// "0.5x"), shared by the speed button and its long-press menu so a picked
    /// speed and the button text always match.
    public nonisolated static func speedLabel(for multiplier: Double) -> String {
        if multiplier == multiplier.rounded() { return "\(Int(multiplier))x" }
        var text = String(format: "%.2f", multiplier)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return "\(text)x"
    }

    /// DUT-583 — advance the voice speed one notch, wrapping from the top (2×)
    /// back to the bottom (0.5×). Drives the single tap on the speed button.
    public func cycleVoiceSpeed() {
        let speeds = VoiceReader.speedMultipliers
        let index = speeds.firstIndex(of: voiceSpeedMultiplier) ?? speeds.firstIndex(of: 1.0) ?? 0
        setVoiceSpeed(speeds[(index + 1) % speeds.count])
    }

    /// DUT-583 — set an exact speed (the long-press menu picks one). Applies the
    /// mapped engine rate and, when a step is *actively* reading, re-speaks it so
    /// the new pace is audible at once. Changing speed while paused or idle only
    /// primes the next utterance — it never starts playback.
    public func setVoiceSpeed(_ multiplier: Double) {
        voiceSpeedMultiplier = multiplier
        voiceReader.speechRate = VoiceReader.rate(for: multiplier)
        if playbackState == .speaking { speakCurrentStep() }
    }

    /// DUT-325 — speed the reader up one notch for the session (not persisted).
    /// Retained for the AC-40.5 command surface; folds into the DUT-583 discrete
    /// speed list so the button, menu, and any voice command stay in lock-step.
    public func speedUp() {
        let speeds = VoiceReader.speedMultipliers
        let index = speeds.firstIndex(of: voiceSpeedMultiplier) ?? speeds.firstIndex(of: 1.0) ?? 0
        setVoiceSpeed(speeds[min(index + 1, speeds.count - 1)])
    }

    /// DUT-325 — slow the reader down one notch for the session (not persisted).
    public func slowDown() {
        let speeds = VoiceReader.speedMultipliers
        let index = speeds.firstIndex(of: voiceSpeedMultiplier) ?? speeds.firstIndex(of: 1.0) ?? 0
        setVoiceSpeed(speeds[max(index - 1, 0)])
    }

    // MARK: - Voice command surface (US-40 / AC-40.5)
    //
    // The four methods below are the in-app control surface the T-690c App
    // Intents will call to drive Cook Mode hands-free via Siri. They are wired
    // here (and exercised in-app + by L1 tests) in T-690b; T-690c only exposes
    // them to SiriKit. Each re-reads through the same AC-40.3 path so a voice
    // command and an on-screen tap behave identically.

    /// "Next step" — advance one step and re-read it when Voice Mode is on.
    /// Same path as the on-screen Next control (AC-7.4 / AC-40.5).
    public func advanceStep() {
        goNext()
    }

    /// "Previous step" / "go back" — step back one and re-read it when Voice
    /// Mode is on. Same path as the on-screen Previous control (AC-40.5).
    public func previousStep() {
        goBack()
    }

    /// "Repeat that" — re-speak the current step without changing position
    /// (AC-40.5). Implicitly interrupts any paused utterance via the reader's
    /// stop-before-speak contract (AC-40.7).
    public func repeatCurrentStep() {
        speakCurrentStep()
    }

    /// "Pause" — pause the current utterance at the next word boundary
    /// (AC-40.4 / AC-40.5). Leaves Voice Mode on so a subsequent navigation or
    /// "repeat" command resumes reading aloud.
    public func pauseVoice() {
        // DUT-620 — with Voice Mode off there's no utterance to pause; mutating
        // playbackState here flipped the transport state spuriously (Siri).
        guard isVoiceModeEnabled else { return }
        voiceReader.pause()
        // DUT-583 — keep the position; the button flips to "play" (resumable).
        playbackState = .paused
    }

    /// "Resume" / "Continue" — resume a paused utterance (DUT-343). Pairs with
    /// ``pauseVoice()``; without it a paused reader could only restart by changing
    /// the step (Next / Previous / Repeat all `stop()` + re-read from the top),
    /// so "Pause" was a hands-free dead-end.
    public func resumeVoice() {
        // DUT-620 — mirror pauseVoice(): don't touch the transport state when
        // Voice Mode is off (there's nothing to resume).
        guard isVoiceModeEnabled else { return }
        voiceReader.resume()
        // DUT-583 — continue from the pause point (no restart); button → pause.
        playbackState = .speaking
    }
}

import DODDomain
import DODIntelligence
import Foundation

/// DUT-1029 — hands-free spoken questions for Cook Mode.
extension CookModeViewModel {

    /// Press-and-hold start. Silences read-aloud (barge-in) so the mic doesn't hear the TTS,
    /// then streams partial transcripts into `liveTranscript`.
    public func beginListening() {
        guard transcriber.isAvailable, !isListening else { return }
        voiceReader.stop()
        playbackState = .idle
        pausedUtteranceIsStale = true
        liveTranscript = ""
        isListening = true
        let stream = transcriber.startListening()
        listenTask = Task { [weak self] in
            for await partial in stream {
                guard let self, !Task.isCancelled else { return }
                self.liveTranscript = partial
            }
        }
    }

    /// Release: stop capture, then answer whatever was heard.
    public func endListening(intelligence: (any DODIntelligenceService)?) async {
        guard isListening else { return }
        transcriber.stopListening()
        // Let the stream drain so `liveTranscript` holds the final text.
        await listenTask?.value
        listenTask = nil
        isListening = false
        let heard = liveTranscript
        liveTranscript = ""
        await handleSpokenQuestion(heard, intelligence: intelligence)
    }

    /// Route a final transcript and speak the result. `intelligence` is nil when the
    /// on-device model is unavailable (then only the deterministic paths answer).
    public func handleSpokenQuestion(_ transcript: String, intelligence: (any DODIntelligenceService)?) async {
        let ingredientLines = recipe.ingredients.map(\.text)
        switch CookQuestionIntent.classify(transcript) {
        case .empty:
            return
        case .nextStep:
            let steps = recipe.instructions.sorted { $0.step < $1.step }
            speakAnswer(CookModeSpokenAnswers.whatsNext(steps: steps, currentStepIndex: currentStepIndex))
        case .previousStep:
            previousStep()
        case .repeatStep:
            replayCurrentStep()
        case .ask(let question):
            guard let intelligence, intelligence.isAvailable else {
                speakAnswer("Sorry, I can't answer that right now.")
                return
            }
            let context = CookModeView.recipeChatContext(
                recipe: recipe,
                ingredientLines: ingredientLines,
                scaleFactor: 1,
                currentStepIndex: currentStepIndex,
                isFinished: isFinished
            )
            let answer = await intelligence.answer(question, imageData: nil, recipeContext: context)
            speakAnswer(answer ?? "Sorry, I don't have an answer for that.")
        }
    }

    /// Speak independent of the Voice Mode toggle; `speak` interrupts any read-aloud (barge-in).
    private func speakAnswer(_ text: String) {
        voiceReader.speak(text)
        if isVoiceModeEnabled { playbackState = .speaking }
        pausedUtteranceIsStale = true  // the step read was cut off; resume re-reads the step
    }
}

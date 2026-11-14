import DODDomain
import DODIntelligence
import Foundation

/// DUT-1029 — hands-free spoken questions for Cook Mode.
extension CookModeViewModel {

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
            let quick = CookModeSpokenAnswers.ingredientAnswer(question: question, ingredientLines: ingredientLines)
            speakAnswer(quick ?? "Sorry, I can't answer that right now.")
        }
    }

    /// Speak independent of the Voice Mode toggle; `speak` interrupts any read-aloud (barge-in).
    private func speakAnswer(_ text: String) {
        voiceReader.speak(text)
        if isVoiceModeEnabled { playbackState = .speaking }
        pausedUtteranceIsStale = true  // the step read was cut off; resume re-reads the step
    }
}

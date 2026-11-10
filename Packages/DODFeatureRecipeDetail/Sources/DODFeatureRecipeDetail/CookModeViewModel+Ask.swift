import DODDomain
import DODIntelligence
import Foundation

/// DUT-1029 — hands-free spoken questions for Cook Mode.
extension CookModeViewModel {

    /// Speak independent of the Voice Mode toggle; `speak` interrupts any read-aloud (barge-in).
    private func speakAnswer(_ text: String) {
        voiceReader.speak(text)
        if isVoiceModeEnabled { playbackState = .speaking }
        pausedUtteranceIsStale = true  // the step read was cut off; resume re-reads the step
    }
}

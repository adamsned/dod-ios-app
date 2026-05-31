import AppIntents
import DODAnalytics
import DODFeatureRecipeDetail
import Foundation

/// Hands-free Cook Mode voice commands exposed to Siri / Shortcuts (US-40).
///
/// Spec trace: US-40 / AC-40.5, CL-83. Each intent is a thin adapter: it posts
/// a ``VoiceCommand`` onto the process-wide ``VoiceCommandBus`` (which the live
/// Cook Mode session registers itself with — see
/// ``CookModeViewModel/beginCookMode()``) and fires a `voiceCommandFired`
/// telemetry event. The bus forwards to the active session's already-tested
/// control method, so a Siri command and an on-screen tap reach identical code
/// (AC-7.4). When Cook Mode isn't foreground the bus has no handler and the
/// command is a silent no-op — Siri can match the phrase from the lock screen
/// without an active session.
///
/// The intents take **no** `recipe` parameter (unlike US-10's `OpenRecipeIntent`)
/// because they act on whatever step the live session is on, and they leave
/// `openAppWhenRun` at its default `false` — there's nothing to drive if Cook
/// Mode isn't already up.

/// "Next step" — advance one step in the active Cook Mode session.
struct NextStepIntent: AppIntent {

    static let title: LocalizedStringResource = "Next Step"
    static let description = IntentDescription(
        "Advances to the next step in Cook Mode."
    )

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceCommandBus.shared.dispatch(.next)
        Telemetry.shared.send(.voiceCommandFired(command: .next))
        return .result()
    }
}

/// "Previous step" / "go back" — step back one in the active Cook Mode session.
struct PreviousStepIntent: AppIntent {

    static let title: LocalizedStringResource = "Previous Step"
    static let description = IntentDescription(
        "Goes back to the previous step in Cook Mode."
    )

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceCommandBus.shared.dispatch(.previous)
        Telemetry.shared.send(.voiceCommandFired(command: .previous))
        return .result()
    }
}

/// "Repeat" / "say that again" — re-read the current step without moving.
struct RepeatStepIntent: AppIntent {

    static let title: LocalizedStringResource = "Repeat Step"
    static let description = IntentDescription(
        "Reads the current Cook Mode step aloud again."
    )

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceCommandBus.shared.dispatch(.repeat)
        Telemetry.shared.send(.voiceCommandFired(command: .repeat))
        return .result()
    }
}

/// "Pause" — pause the current spoken step at the next word boundary.
struct PauseVoiceIntent: AppIntent {

    static let title: LocalizedStringResource = "Pause Reading"
    static let description = IntentDescription(
        "Pauses Cook Mode reading the current step aloud."
    )

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceCommandBus.shared.dispatch(.pause)
        Telemetry.shared.send(.voiceCommandFired(command: .pause))
        return .result()
    }
}

import AppIntents
import DODFeatureRecipeDetail
import Foundation

/// Hands-free Cook Mode voice commands exposed to Siri / Shortcuts (US-40).
///
/// Spec trace: US-40 / AC-40.5, CL-83. Each intent is a thin adapter: it posts
/// a ``VoiceCommand`` onto the process-wide ``VoiceCommandBus`` (which the live
/// Cook Mode session registers itself with — see
/// ``CookModeViewModel/beginCookMode()``). The bus forwards to the active
/// session's already-tested control method, so a Siri command and an on-screen
/// tap reach identical code (AC-7.4). When Cook Mode isn't foreground the bus
/// has no handler and the command is a silent no-op — Siri can match the phrase
/// from the lock screen without an active session.
///
/// DUT-637 — the `voiceCommandFired` telemetry is emitted by the bus's
/// ``VoiceCommandBus/deliver(_:)`` ONLY when a handler consumed the command, so
/// a no-op lock-screen dispatch no longer logs a phantom "fired" event. The
/// intents therefore just dispatch and return.
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
        return .result()
    }
}

/// "Resume" — resume the paused spoken step (DUT-343), so "Pause" isn't a
/// hands-free dead-end.
struct ResumeVoiceIntent: AppIntent {

    static let title: LocalizedStringResource = "Resume Reading"
    static let description = IntentDescription(
        "Resumes Cook Mode reading the current step aloud after a pause."
    )

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceCommandBus.shared.dispatch(.resume)
        return .result()
    }
}

/// DUT-1388 — ONE App Shortcut for all five hands-free commands.
///
/// Apple caps an app at 10 App Shortcuts, and the five voice commands above
/// used five of them. This intent takes the command as an `AppEnum` whose case
/// titles + synonyms are exactly the old phrases' verbs, so the single phrase
/// "\(command) in Dutch Oven Daddy" still matches "Next step", "Go back",
/// "Say that again", "Pause", "Continue reading", and the rest. The five
/// single-purpose intents stay (Shortcuts the cook already built keep working);
/// they just no longer register their own App Shortcut.
struct CookModeCommandIntent: AppIntent {

    static let title: LocalizedStringResource = "Cook Mode Command"
    static let description = IntentDescription(
        "Moves between steps or pauses and resumes reading in Cook Mode."
    )

    @Parameter(title: "Command")
    var command: CookModeCommandOption

    init() {}

    init(command: CookModeCommandOption) {
        self.command = command
    }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$command) in Cook Mode")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceCommandBus.shared.dispatch(command.voiceCommand)
        return .result()
    }
}

/// The spoken command. Titles + synonyms ARE the Siri vocabulary (see
/// ``CookModeCommandIntent``), carried over from the five retired App Shortcuts.
enum CookModeCommandOption: String, AppEnum {
    case next
    case previous
    case `repeat`
    case pause
    case resume

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Cook Mode Command")
    }

    static var caseDisplayRepresentations: [CookModeCommandOption: DisplayRepresentation] {
        [
            .next: DisplayRepresentation(title: "Next step", synonyms: ["Next", "Go forward"]),
            .previous: DisplayRepresentation(title: "Previous step", synonyms: ["Go back", "Back"]),
            .repeat: DisplayRepresentation(title: "Repeat step", synonyms: ["Repeat that", "Say that again"]),
            .pause: DisplayRepresentation(title: "Pause reading", synonyms: ["Pause"]),
            .resume: DisplayRepresentation(title: "Resume reading", synonyms: ["Continue reading"]),
        ]
    }

    var voiceCommand: VoiceCommand {
        switch self {
        case .next: .next
        case .previous: .previous
        case .repeat: .repeat
        case .pause: .pause
        case .resume: .resume
        }
    }
}

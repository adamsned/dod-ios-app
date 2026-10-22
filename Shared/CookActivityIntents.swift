import AppIntents
import Foundation

/// DUT-988 — the two buzzer-card buttons.
enum CookActivityIntentCommand: Sendable {
    case pulledIt
    case snooze
}

/// Set by the app at launch (DODApp.init). In the extension it stays nil —
/// `LiveActivityIntent.perform()` always runs in the app process.
@MainActor
enum CookActivityIntentRouter {
    static var handler: (@MainActor (CookActivityIntentCommand) -> Void)?
}

/// "Pulled It" — advance the step without unlocking or opening the app.
struct PulledItIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pulled It"
    static let description = IntentDescription("Advances to the next Cook Mode step.")
    init() {}
    @MainActor
    func perform() async throws -> some IntentResult {
        CookActivityIntentRouter.handler?(.pulledIt)
        return .result()
    }
}

/// "2 More Min" — snooze the buzzed timer for two minutes.
struct SnoozeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "2 More Min"
    static let description = IntentDescription("Adds two more minutes to the timer that just buzzed.")
    init() {}
    @MainActor
    func perform() async throws -> some IntentResult {
        CookActivityIntentRouter.handler?(.snooze)
        return .result()
    }
}
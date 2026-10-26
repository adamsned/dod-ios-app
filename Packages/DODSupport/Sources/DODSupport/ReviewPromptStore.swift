import Foundation

/// DUT-157 — local-only engagement counters for the App Store review prompt. No PII.
///
/// `@unchecked Sendable` matches ``PanCareStore``: the only stored property is a
/// `let UserDefaults`, which Apple documents as thread-safe.
public struct ReviewPromptStore: @unchecked Sendable {
    static let prefix = "dod.reviewPrompt."
    private let defaults: UserDefaults

    /// Test seam — inject a throwaway `UserDefaults(suiteName:)`.
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var sessionCount: Int { defaults.integer(forKey: Self.prefix + "sessions") }
    public var recipeViewCount: Int { defaults.integer(forKey: Self.prefix + "recipeViews") }
    public var completedCookCount: Int { defaults.integer(forKey: Self.prefix + "completedCooks") }

    /// Start of the last prompt we issued (nil = never).
    public var lastPromptDate: Date? {
        get { defaults.object(forKey: Self.prefix + "lastPrompt") as? Date }
        nonmutating set { defaults.set(newValue, forKey: Self.prefix + "lastPrompt") }
    }

    /// Set when the user declined (opted out of) the prompt. Suppresses all future automatic prompts.
    public var declined: Bool {
        get { defaults.bool(forKey: Self.prefix + "declined") }
        nonmutating set { defaults.set(newValue, forKey: Self.prefix + "declined") }
    }

    public func recordSession() { bump("sessions") }
    public func recordRecipeView() { bump("recipeViews") }
    public func recordCompletedCook() { bump("completedCooks") }

    private func bump(_ name: String) {
        let key = Self.prefix + name
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }
}

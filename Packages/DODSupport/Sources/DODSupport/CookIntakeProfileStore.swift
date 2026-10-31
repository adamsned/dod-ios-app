import Foundation

/// DUT-1032 — local-only store for the onboarding intake result.
///
/// `@unchecked Sendable` matches ``PanCareStore``: the only stored property is a
/// `let UserDefaults`, which Apple documents as thread-safe.
public struct CookIntakeProfileStore: @unchecked Sendable {
    static let key = "dod.cookIntake.profile"
    static let completedKey = "dod.cookIntake.completed"
    private let defaults: UserDefaults

    /// Test seam — inject a throwaway `UserDefaults(suiteName:)`.
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// The saved profile, or nil if the intake was skipped / never run.
    public func profile() -> CookIntakeProfile? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(CookIntakeProfile.self, from: data)
    }

    public func save(_ profile: CookIntakeProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Self.key)
        defaults.set(true, forKey: Self.completedKey)
    }

    /// True once the intake was saved OR explicitly skipped (so it is never re-offered).
    public var isCompleted: Bool { defaults.bool(forKey: Self.completedKey) }

    public func markSkipped() { defaults.set(true, forKey: Self.completedKey) }
}

import Foundation

/// Persists the dietary profile as JSON in UserDefaults (DUT-126).
/// An absent or corrupt value reads as the empty default profile.
///
/// `@unchecked Sendable` matches ``CookIntakeProfileStore``: the only stored property is a
/// `let UserDefaults`, which Apple documents as thread-safe.
public struct DietaryProfileStore: @unchecked Sendable {
    public static let defaultsKey = "dod.dietaryProfile.v1"
    private let defaults: UserDefaults

    /// Test seam: inject a throwaway `UserDefaults(suiteName:)`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> DietaryProfile {
        guard let data = defaults.data(forKey: Self.defaultsKey),
            let profile = try? JSONDecoder().decode(DietaryProfile.self, from: data)
        else { return DietaryProfile() }
        return profile
    }
}

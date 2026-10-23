import Foundation

/// DUT-982 — stores the quiz answers as JSON in UserDefaults.
public enum CookerIntakeStore {
    public static let defaultsKey = "dod.onboarding.cookerIntake.v1"

    public static func load(from defaults: UserDefaults = .standard) -> CookerIntake? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(CookerIntake.self, from: data)
    }

    public static func save(_ intake: CookerIntake, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(intake) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}

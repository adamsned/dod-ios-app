import Foundation

/// DUT-117 — on-device persistence for the Recipe of the Day. Stores only recipe
/// ids and a calendar day key: no user identifier, no profile data.
struct RecipeOfTheDayStore: @unchecked Sendable {
    /// How many recent picks are excluded from the next pick.
    static let historyLimit = 30

    private let defaults: UserDefaults
    private let dayKeyKey = "recipeOfTheDay.dayKey"
    private let idKey = "recipeOfTheDay.id"
    private let historyKey = "recipeOfTheDay.history"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// "yyyy-MM-dd" for `date` in `calendar` (local calendar day).
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The id stored for `dayKey`, or nil when none (or a different day) is stored.
    func pickedID(forDayKey dayKey: String) -> Int? {
        guard defaults.string(forKey: dayKeyKey) == dayKey, defaults.object(forKey: idKey) != nil else {
            return nil
        }
        return defaults.integer(forKey: idKey)
    }

    /// Most-recent-first ids, at most `historyLimit`.
    func recentIDs() -> [Int] {
        defaults.array(forKey: historyKey) as? [Int] ?? []
    }

    func record(id: Int, dayKey: String) {
        defaults.set(dayKey, forKey: dayKeyKey)
        defaults.set(id, forKey: idKey)
        let history = ([id] + recentIDs().filter { $0 != id }).prefix(Self.historyLimit)
        defaults.set(Array(history), forKey: historyKey)
    }
}

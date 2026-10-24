import Foundation

/// DUT-131 — opt-in "Keep saved recipes available offline" preference.
/// Backed by `UserDefaults` so it persists across launches and needs no
/// SwiftData schema change. Mirrors the `RecentSearches` store style.
public final class OfflineSettings: @unchecked Sendable {

    /// Shared key so a SwiftUI `@AppStorage` toggle and this type read the
    /// same value. The `.v1` suffix lets a future format rotate the key.
    public static let keepSavedOfflineKey = "dod.offline.keepSavedRecipes.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Defaults to `false` when the key has never been written.
    public var keepSavedRecipesOffline: Bool {
        get { defaults.bool(forKey: Self.keepSavedOfflineKey) }
        set { defaults.set(newValue, forKey: Self.keepSavedOfflineKey) }
    }
}

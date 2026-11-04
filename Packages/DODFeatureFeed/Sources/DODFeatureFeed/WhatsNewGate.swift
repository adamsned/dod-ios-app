import Foundation

/// DUT-174 — decides whether the post-update changelog should show (once per version).
public enum WhatsNewGate {
    public static let lastSeenKey = "whatsNew.lastSeenVersion"

    /// Marketing version from the bundle, "0" when missing.
    public static func currentVersion(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    public static func lastSeen(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: lastSeenKey)
    }

    /// Fresh install (nothing stored): record the current version silently so no backlog is shown.
    public static func baselineIfNeeded(currentVersion: String, defaults: UserDefaults = .standard) {
        if defaults.string(forKey: lastSeenKey) == nil {
            defaults.set(currentVersion, forKey: lastSeenKey)
        }
    }

    public static func markSeen(_ version: String, defaults: UserDefaults = .standard) {
        defaults.set(version, forKey: lastSeenKey)
    }

    /// True only when a stored version exists and the current one is strictly newer.
    public static func shouldPresent(currentVersion: String, lastSeenVersion: String?) -> Bool {
        guard let lastSeenVersion else { return false }
        return WhatsNewProvider.isNewer(currentVersion, than: lastSeenVersion)
    }
}

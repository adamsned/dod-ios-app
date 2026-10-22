import Foundation

/// DUT-971 — local-only maintenance log for the cast-iron care coach.
///
/// `@unchecked Sendable` matches ``ControlRouteStore``: the only stored
/// property is a `let UserDefaults`, which Apple documents as thread-safe; the
/// Foundation header just isn't audited for Swift 6 Sendability yet.
public struct PanCareStore: @unchecked Sendable {
    static let key = "dod.panCare.entries"
    /// Cap so the blob stays small.
    static let maxEntries = 200
    private let defaults: UserDefaults

    /// Test seam — inject a throwaway `UserDefaults(suiteName:)`.
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Newest first.
    public func entries() -> [PanCareEntry] {
        guard let data = defaults.data(forKey: Self.key),
            let decoded = try? JSONDecoder().decode([PanCareEntry].self, from: data)
        else { return [] }
        return decoded.sorted { $0.careAt > $1.careAt }
    }
}

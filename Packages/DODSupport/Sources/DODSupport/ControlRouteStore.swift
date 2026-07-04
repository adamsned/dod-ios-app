import Foundation

/// DUT-480 / CL-301 — a one-shot "pending route" flag the iOS 18 Control Center
/// control writes and the main app consumes on next activation.
///
/// A `ControlWidget` can't reliably hand the app a `dod://` URL: an
/// `OpenURLIntent` fired from a Control doesn't dependably foreground the app,
/// so the `onOpenURL` → ``WidgetDeepLinkParser`` path never runs. Instead the
/// control's `AppIntent` sets `openAppWhenRun = true` (the system foregrounds
/// us) AND drops this flag into the shared App Group; ``RootView`` reads +
/// clears it on cold launch and on every `.active` transition, then routes to
/// the Shopping List. The flag is take-once so a stale value can't re-trigger.
///
/// `@unchecked Sendable` matches ``WidgetSnapshotStore``: the only stored
/// property is a `let UserDefaults`, which Apple documents as thread-safe; the
/// Foundation header just isn't audited for Swift 6 Sendability yet.
public struct ControlRouteStore: @unchecked Sendable {

    /// The routes a control can request. Only the Shopping List today; raw
    /// values are the persisted tokens (stable across binary versions).
    ///
    /// DUT-560 — the configurable iOS 18 Control Center control lets the user
    /// pick which of the six cooking tools it opens, so every tool has a stable
    /// token here.
    public enum Route: String, Sendable {
        case shoppingList = "shopping-list"
        case heatCoach = "heat-coach"
        case cookingJournal = "journal"
        case firstCookout = "first-cookout"
        case cookMode = "cook-mode"
        case buyBuzzyWaxx = "buzzywaxx"
    }

    private let defaults: UserDefaults
    private static let key = "dod.control.pendingRoute"

    /// App Group-backed store the app and widget extension share. Fails only
    /// when the suite can't be opened (misconfigured entitlement), matching
    /// ``WidgetSnapshotStore``'s failable init.
    public init?(suiteName: String = WidgetSnapshotConfig.appGroupIdentifier) {
        guard let suite = UserDefaults(suiteName: suiteName) else { return nil }
        defaults = suite
    }

    /// Test seam — inject a throwaway `UserDefaults(suiteName:)` so tests never
    /// touch the real App Group suite or `.standard`.
    public init(defaults: UserDefaults) { self.defaults = defaults }

    /// Record the route the app should open on its next activation. Called from
    /// the control's `AppIntent.perform()`.
    public func setPending(_ route: Route) { defaults.set(route.rawValue, forKey: Self.key) }

    /// Read + clear the pending route (take-once). Returns `nil` when nothing is
    /// pending or the persisted token is unrecognized; the removal happens
    /// whenever a value was present so a stale token can't re-fire.
    public func takePending() -> Route? {
        guard let raw = defaults.string(forKey: Self.key) else { return nil }
        defaults.removeObject(forKey: Self.key)
        return Route(rawValue: raw)
    }
}

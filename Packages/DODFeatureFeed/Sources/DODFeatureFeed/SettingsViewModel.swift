import DODPersistence
import Foundation
import Observation

/// State + persistence for the Settings page (US-32 skeleton, US-36 expansion,
/// US-41 iCloud Sync row).
///
/// The T-550 skeleton (US-32) owned exactly one piece of persisted state —
/// the "Use metric units" toggle — and stubbed the rest of the surface as
/// version footer + About link. T-630 (US-36) expanded the view-model to
/// also persist the four new round-trip preferences the round-7 backlog
/// graduated and to own the cache-clear flow's snackbar feedback. T-703
/// (US-41) further extends the view-model with the iCloud Sync toggle —
/// reads + writes the canonical `RecipeStore.cloudKitSyncOptInKey`
/// UserDefaults flag and routes the flag-write + container rebuild through
/// a `SettingsDependencies` seam so the composition root owns the
/// `RecipeStore` lifecycle (per CL-89).
///
/// Persistence keys (the `dod.settings.*` prefix US-32 established, plus
/// the `dod.cloudkit.*` namespace T-702 / T-703 own):
/// - ``useMetricUnitsKey`` — Bool, AC-32.4 (US-32, T-551 follow-up consumes).
/// - ``notificationsEnabledKey`` — Bool, AC-36.1 (US-36, T-631 follow-up
///   wires APNs).
/// - ``appearancePreferenceKey`` — `AppearancePreference.rawValue` string,
///   AC-36.2 (US-36, `RootView.preferredColorScheme(...)` consumes).
/// - ``shareFormatPreferenceKey`` — `ShareFormatPreference.rawValue` string,
///   AC-36.3 (US-36, future task wires `ShareLink`'s payload).
/// - ``telemetryEnabledKey`` — Bool, AC-36.5 (US-36,
///   `TelemetryDeckTransport.send(_:)` consumes the same key).
/// - `RecipeStore.cloudKitSyncOptInKey` (`dod.cloudkit.syncOptInV1`) — Bool,
///   AC-41.3 (US-41, T-702's container factory reads it; T-703 / T-704
///   write it). NOTE: declared in `DODPersistence` so the canonical key
///   string lives next to the reader; the view-model goes through
///   ``SettingsDependencies`` rather than touching `UserDefaults` directly
///   so the post-write `recreateContainerAfterOptInChange()` rebuild fires
///   atomically.
///
/// `UserDefaults` is constructor-injected so the L1 unit suite can pass an
/// isolated suite (`UserDefaults(suiteName:)`) without polluting the shared
/// standard defaults — pattern mirrors `RecentSearches` in `DODFeatureSearch`.
///
/// Spec trace: US-32 AC-32.4; US-36 AC-36.1..AC-36.8; US-41 AC-41.3, AC-41.4.
@Observable
@MainActor
public final class SettingsViewModel {

    // MARK: - UserDefaults keys
    //
    // Keys are declared `nonisolated` so the enum-side `fromDefaults(_:)`
    // helpers + `@AppStorage` literals (which run outside the MainActor
    // context) can reference them without an actor hop. The keys are
    // pure compile-time constants — no MainActor isolation is needed.

    /// AC-32.4 — "Use metric units" toggle key.
    public nonisolated static let useMetricUnitsKey = "dod.settings.useMetricUnits"

    /// AC-36.1 — "Notify me when new recipes drop" toggle key. Defaults
    /// OFF on first launch; T-631 follow-up wires APNs authorization
    /// when the user flips it ON.
    public nonisolated static let notificationsEnabledKey = "dod.settings.notificationsEnabled"

    /// AC-36.2 — Appearance preference key. Value is the raw value of
    /// ``AppearancePreference`` (`"system"` / `"light"` / `"dark"`).
    /// Defaults to `.system` (no explicit preferredColorScheme override).
    public nonisolated static let appearancePreferenceKey = "dod.settings.appearance"

    /// AC-36.3 — Default share format preference key. Value is the raw
    /// value of ``ShareFormatPreference`` (`"linkOnly"` / `"linkAndText"`).
    /// Defaults to `.linkOnly` — preserves the existing AC-6.2 share flow
    /// byte-for-byte until a future task wires the link-plus-text payload.
    public nonisolated static let shareFormatPreferenceKey = "dod.settings.shareFormat"

    /// AC-36.5 — Share Anonymous Usage Data toggle key. Defaults ON
    /// (matches constitution §9's opt-out posture). Read at every
    /// `TelemetryDeckTransport.send(_:)` call; production transport
    /// short-circuits when this flag is false.
    public nonisolated static let telemetryEnabledKey = "dod.settings.telemetryEnabled"

    private let defaults: UserDefaults
    /// Optional seam for the iCloud Sync row's flag-write +
    /// container-rebuild dispatch (US-41 / AC-41.3). Constructor-injected
    /// so the L1 suite can pass a recording double; production wiring
    /// passes a `LiveSettingsDependencies` value that drives
    /// `RecipeStore.recreateContainerAfterOptInChange()`. The default
    /// `nil` keeps existing call sites (previews, snapshot hosts, the
    /// pre-T-703 test fixtures) compiling without churn — those surfaces
    /// just won't trigger the rebuild. Read from the iCloud Sync action
    /// methods that live in `SettingsViewModel+CloudSync.swift` (the
    /// file_length split forces an internal-but-not-private accessor).
    let cloudSyncDependency: (any SettingsDependencies)?

    /// Authorization seam for the notifications toggle (US-42 / AC-42.1).
    /// The composition root injects a closure that calls
    /// `NotificationService.requestAuthorization()` (which wraps
    /// `UNUserNotificationCenter.current().requestAuthorization(...)`);
    /// it returns `true` iff the user grants. Defaults to a closure that
    /// reports "not granted" so previews / snapshot hosts / the L1 suite
    /// never touch `UserNotifications` — the view-model package builds on
    /// the macOS `swift test` slice where that framework is unavailable.
    private let requestNotificationAuthorization: @MainActor () async -> Bool

    // MARK: - Persisted state

    /// AC-32.4. Reads + writes through ``defaults`` so a parallel write
    /// from another surface (e.g. a future Settings sync feature) is
    /// observed on the next read.
    public var useMetricUnits: Bool {
        get { defaults.bool(forKey: Self.useMetricUnitsKey) }
        set { defaults.set(newValue, forKey: Self.useMetricUnitsKey) }
    }

    /// AC-36.1. Defaults to false; `defaults.bool(forKey:)` returns false
    /// for an absent key which is the documented v1 starting state.
    public var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Self.notificationsEnabledKey) }
        set { defaults.set(newValue, forKey: Self.notificationsEnabledKey) }
    }

    /// AC-36.2. Defaults to ``AppearancePreference/system`` when the key
    /// is absent or carries a value that doesn't decode to a known case
    /// (defensive — preserves Match-System behavior under any future
    /// rename or migration).
    public var appearance: AppearancePreference {
        get { AppearancePreference.fromDefaults(defaults) }
        set { defaults.set(newValue.rawValue, forKey: Self.appearancePreferenceKey) }
    }

    /// AC-36.3. Defaults to ``ShareFormatPreference/linkOnly`` when the
    /// key is absent or carries an unknown value — same defensive
    /// fallback as ``appearance``.
    public var shareFormat: ShareFormatPreference {
        get { ShareFormatPreference.fromDefaults(defaults) }
        set { defaults.set(newValue.rawValue, forKey: Self.shareFormatPreferenceKey) }
    }

    /// AC-36.5. Defaults ON (true). The read uses
    /// `object(forKey:) as? Bool ?? true` so an absent key returns true,
    /// matching the constitution §9 opt-out posture. A future opt-in
    /// flip would change the default at this getter (and update the
    /// `TelemetryDeckTransport` gate to match).
    public var telemetryEnabled: Bool {
        get { Self.telemetryEnabled(in: defaults) }
        set { defaults.set(newValue, forKey: Self.telemetryEnabledKey) }
    }

    /// Default-aware read of the telemetry flag. Exposed as a static so
    /// `TelemetryDeckTransport` (and any other consumer that wants to
    /// honor the user's privacy preference without depending on this
    /// package directly) can call the exact same read. Marked
    /// `nonisolated` so off-MainActor consumers can call it freely.
    public nonisolated static func telemetryEnabled(in defaults: UserDefaults) -> Bool {
        (defaults.object(forKey: Self.telemetryEnabledKey) as? Bool) ?? true
    }

    // MARK: - US-41 / AC-41.3 — iCloud Sync toggle

    /// Cached snapshot of the iCloud sync opt-in flag so the
    /// `@Observable` machinery emits a change when the view-model
    /// flips it. The setter is intentionally not the public write
    /// path — view-layer code calls ``requestCloudSyncOptIn(_:)``
    /// instead so the confirmation alert flow stays mandatory
    /// (per AC-41.3 + CL-89). The getter mirrors what the dependency
    /// reports the first time it's read, so previews + tests that
    /// don't wire a dependency still get a stable `false` default.
    /// Setter is `internal` (not `public`) so the iCloud-sync action
    /// methods in `SettingsViewModel+CloudSync.swift` can mutate it
    /// while external callers stay locked out.
    public internal(set) var isCloudSyncEnabled: Bool

    /// Placeholder for the AC-41.7 status sublabel. T-705 wires the
    /// real `CloudKitSyncStatus` enum + the "Last synced N ago"
    /// rendering on top of this string; T-703 reserves the surface so
    /// the Settings row layout doesn't shift when T-705 lands.
    /// Returns `"Idle"` today — the user just turned sync on, no
    /// round-trip has happened yet, and we don't crash by trying to
    /// format a `nil` last-synced date as "N ago".
    public var cloudSyncStatusText: String { "Idle" }

    /// State for the confirmation alert that fronts every toggle flip
    /// per AC-41.3 / CL-89. `nil` when no alert is showing; otherwise
    /// describes the direction (on → off vs off → on) so the view
    /// renders the right copy + button labels. The view binds an
    /// `isPresented` binding via ``cloudSyncConfirmationIsPresented``
    /// and reads the request payload to build the alert.
    /// Setter is `internal` so the iCloud-sync action methods in
    /// `SettingsViewModel+CloudSync.swift` can mutate it while
    /// external callers stay locked out.
    public internal(set) var cloudSyncConfirmationRequest: CloudSyncConfirmationRequest?

    // MARK: - Snackbar feedback (Clear Cache row)

    /// AC-36.4. Latest snackbar message from the Clear Cache action.
    /// The view binds a `Snackbar` to this when non-nil and dismisses
    /// it via ``dismissSnackbar()``. `nil` means no snackbar is showing.
    public private(set) var snackbarMessage: String?

    public init(
        defaults: UserDefaults = .standard,
        dependencies: (any SettingsDependencies)? = nil,
        requestNotificationAuthorization: @escaping @MainActor () async -> Bool = { false }
    ) {
        self.defaults = defaults
        self.cloudSyncDependency = dependencies
        self.requestNotificationAuthorization = requestNotificationAuthorization
        // US-41 AC-41.3 — seed the toggle state from the canonical
        // flag (RecipeStore.cloudKitSyncOptInKey) so users who already
        // opted in via T-704's first-launch sheet see the toggle in the
        // ON position the first time they open Settings. When no
        // dependency is wired (previews / snapshot hosts / pre-T-703
        // test fixtures), fall through to a direct defaults read so
        // the surface still reflects the persisted value.
        if let dependencies {
            self.isCloudSyncEnabled = dependencies.cloudSyncOptInValue()
        } else {
            self.isCloudSyncEnabled = defaults.bool(forKey: RecipeStore.cloudKitSyncOptInKey)
        }
    }

    // MARK: - Notifications toggle (US-42 / AC-42.1)

    /// Drives the notifications toggle's ON/OFF transition. Turning **ON**
    /// requests system authorization (AC-42.1): on grant the flag persists
    /// `true`; on deny the flag stays `false` (the toggle reverts) and a
    /// snackbar points the user at iOS Settings. Turning **OFF** simply
    /// persists `false` — no system call. Returns the resolved on/off
    /// state so the view's binding can reflect a denied prompt without a
    /// separate observation hop.
    @discardableResult
    public func setNotificationsEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            notificationsEnabled = false
            return false
        }
        let granted = await requestNotificationAuthorization()
        notificationsEnabled = granted
        if !granted {
            // Persisted intent stays OFF so the UI never claims notifications
            // are on while the OS suppresses them (AC-42.1).
            snackbarMessage = "Enable notifications in iOS Settings → DOD to get new-post alerts."
        }
        return granted
    }

    // US-41 / AC-41.3 — iCloud Sync toggle actions live in
    // `SettingsViewModel+CloudSync.swift` to keep this file inside the
    // SwiftLint 400-line file_length cap (the same partitioning rule
    // RecipeStore + RecipeStore+Containers.swift follows in DODPersistence).

    // MARK: - Clear cached recipe images (AC-36.4)

    /// Calls through the supplied closure (which routes to
    /// `RecipeStore.clearImageCache()` in production) and surfaces a
    /// snackbar with the freed-byte total formatted as MB. The
    /// zero-byte branch shows "Cache was already clear." so the user
    /// always sees feedback for the tap (no silent no-op). The
    /// view-model stays free of a hard `DODPersistence` dependency —
    /// the call-site (composition root) supplies the store-backed
    /// closure; tests can inject a stub closure to exercise the
    /// freed-MB formatter and error path independently.
    public func clearImageCache(onClear: () async throws -> Int) async {
        do {
            let freedBytes = try await onClear()
            snackbarMessage = Self.cacheClearMessage(freedBytes: freedBytes)
        } catch {
            // Best-effort — the store actor's SwiftData writes are
            // already wrapped in `try modelContext.save()` which surfaces
            // here on persistence failure. Surface a humane error rather
            // than silently failing.
            snackbarMessage = "Couldn't clear cache — try again."
        }
    }

    /// Pure formatter for the cache-clear snackbar copy. Extracted as a
    /// `static` so the L1 unit test can pin the MB-rendering + zero-case
    /// behavior without spinning up a `RecipeStore`.
    public static func cacheClearMessage(freedBytes: Int) -> String {
        guard freedBytes > 0 else {
            return "Cache was already clear."
        }
        let megabytes = Double(freedBytes) / (1024.0 * 1024.0)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        let mbString = formatter.string(from: NSNumber(value: megabytes)) ?? "0.0"
        return "Freed \(mbString) MB of cached images."
    }

    public func dismissSnackbar() {
        snackbarMessage = nil
    }

    /// Preview / snapshot-host fallback. Sets the zero-case snackbar
    /// copy so design surfaces (previews, snapshot tests) can render the
    /// snackbar without a real `RecipeStore` dependency. Production
    /// call sites always delegate through ``clearImageCache(via:)``.
    public func previewCacheClearMessage() {
        snackbarMessage = Self.cacheClearMessage(freedBytes: 0)
    }

    // MARK: - Version footer

    /// Display string for the version footer row, e.g. `"v1.0.2 (47)"`.
    /// Reads `CFBundleShortVersionString` + `CFBundleVersion` from the
    /// supplied bundle (defaults to `Bundle.main` in production; tests
    /// pass a fixture bundle if they want deterministic strings).
    ///
    /// Spec trace: US-32 AC-32.3 row 3.
    public static func versionFooter(bundle: Bundle = .main) -> String {
        let info = bundle.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "—"
        let build = info["CFBundleVersion"] as? String ?? "—"
        return "v\(version) (\(build))"
    }
}

// `CloudSyncConfirmationRequest` lives in
// `SettingsViewModel+CloudSync.swift` alongside the iCloud Sync action
// methods (file_length split — see that file's header for rationale).

// MARK: - Appearance preference (AC-36.2)

/// User-selected appearance preference. Drives `RootView`'s
/// `.preferredColorScheme(...)` modifier: `.system` leaves the modifier's
/// value `nil` (so the OS-level setting wins), `.light` / `.dark` force
/// the SwiftUI environment value regardless of OS preference.
///
/// Raw values are the on-disk wire format — never rename without a
/// migration shim because the values land in `UserDefaults` on every
/// user's device that has touched the Appearance picker.
///
/// Spec trace: US-36 AC-36.2.
public enum AppearancePreference: String, CaseIterable, Sendable, Hashable {
    case system
    case light
    case dark

    /// Human-readable label rendered in the picker row.
    public var displayName: String {
        switch self {
        case .system: "Match System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Default-aware read. An absent key OR an unknown raw value falls
    /// back to ``system`` so a malformed migration / forward-compat
    /// situation never crashes — Match System is the safe default.
    public static func fromDefaults(_ defaults: UserDefaults) -> AppearancePreference {
        guard
            let raw = defaults.string(forKey: SettingsViewModel.appearancePreferenceKey),
            let value = AppearancePreference(rawValue: raw)
        else {
            return .system
        }
        return value
    }
}

// MARK: - Share format preference (AC-36.3)

/// Default share format preference. Today the recipe-detail share path
/// (`RecipeDetailView.ShareLink`) emits the canonical URL only —
/// ``linkOnly`` preserves that AC-6.2 behavior byte-for-byte. The
/// ``linkAndText`` case is persisted but not yet consumed: a future
/// task wires the recipe excerpt into the share payload.
///
/// Raw values are the on-disk wire format — same caveat as
/// ``AppearancePreference``: don't rename without a migration shim.
///
/// Spec trace: US-36 AC-36.3.
public enum ShareFormatPreference: String, CaseIterable, Sendable, Hashable {
    case linkOnly
    case linkAndText

    /// Human-readable label rendered in the picker row.
    public var displayName: String {
        switch self {
        case .linkOnly: "Just the link"
        case .linkAndText: "Link + recipe text"
        }
    }

    /// Default-aware read. Absent / malformed values fall back to
    /// ``linkOnly`` — the existing AC-6.2 share contract.
    public static func fromDefaults(_ defaults: UserDefaults) -> ShareFormatPreference {
        guard
            let raw = defaults.string(forKey: SettingsViewModel.shareFormatPreferenceKey),
            let value = ShareFormatPreference(rawValue: raw)
        else {
            return .linkOnly
        }
        return value
    }
}

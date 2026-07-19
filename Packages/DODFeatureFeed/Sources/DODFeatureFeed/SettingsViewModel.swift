import DODFeatureProfile
import DODPersistence
import DODSupport
import Foundation
import Observation

/// State + persistence for the Settings page (US-32 skeleton, US-36
/// expansion, US-41 iCloud Sync row, US-44 Profile section). Persisted
/// keys live under `dod.settings.*` + `dod.cloudkit.*`; the picker
/// preferences (`appearance` / `temperaturePreference` / `voiceGender`)
/// are `@Observable` stored properties as of T-756 / CL-153 so the picker
/// labels + the sheet theme update live (DUT-62).
///
/// `UserDefaults` is constructor-injected so the L1 unit suite can pass an
/// isolated `UserDefaults(suiteName:)`. The Profile section's ``profile``
/// + ``profileStore`` are constructor-injected by the composition root.
///
/// Spec trace: US-32 AC-32.4; US-36 AC-36.1..AC-36.8; US-41 AC-41.3, AC-41.4;
/// US-44 AC-44.1, AC-44.4; CL-153.
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

    /// AC-36.1 — "When New Recipes Drop" toggle key (the row was renamed
    /// from "Notify me when new recipes drop" in T-750 / CL-147; the key
    /// is unchanged so the persisted preference survives the rename).
    /// Defaults OFF on first launch; T-631 follow-up wires APNs
    /// authorization when the user flips it ON.
    public nonisolated static let notificationsEnabledKey = "dod.settings.notificationsEnabled"

    /// T-750 / CL-147 (DUT-56) — "When Someone Replies to My Comment"
    /// toggle key. Defaults OFF. Secures notification permission on enable
    /// like ``notificationsEnabledKey``; reply-alert delivery awaits a
    /// server-side push trigger (the DUT-15 backend gap). `V1` suffix.
    public nonisolated static let commentReplyNotificationsEnabledKey =
        "dod.settings.commentReplyNotificationsEnabledV1"

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

    /// `internal` (not `private`) so the voice-section accessors in
    /// `SettingsViewModel+Voice.swift` can read the dismissal flag via the same
    /// store the rest of the view-model uses (the file_length split forces
    /// internal-but-not-private accessors, exactly as the iCloud Sync split did).
    let defaults: UserDefaults

    /// US-40 / AC-40.10..AC-40.11 (T-721). Backs the Cook Mode voice-gender
    /// picker. Built against the same injected ``defaults`` so the L1 suite
    /// drives it through an isolated `UserDefaults(suiteName:)`.

    /// US-40 / AC-40.12..AC-40.13 (T-721 quality readout + Preview, T-722
    /// nudge). Catalog + preview seam for the Settings voice section. Optional
    /// so previews / snapshot hosts / pre-T-721 fixtures build a view-model
    /// without an AVFoundation dependency — when `nil` the readout reads
    /// "unknown" and the nudge stays hidden (a missing catalog must never
    /// surface a false "you're on a robotic voice" claim). `internal` (not
    /// `private`) so the accessors in `SettingsViewModel+Voice.swift` reach
    /// it across the file_length split.
    let voicePreviewer: (any VoicePreviewing)?

    /// The language whose installed voices drive the quality readout + nudge +
    /// preview — the device's current language per AC-40.2 / CL-79. Captured at
    /// init. `internal` for the same cross-file-extension reason as
    /// ``voicePreviewer``.
    let voiceLanguageCode: String?

    /// Seam for the iCloud Sync row (US-41 / AC-41.3; DUT-6). Production
    /// wiring persists the `RecipeStore.cloudKitSyncOptInKey` launch-time
    /// flag and reports the CloudKit mirror status. `nil` for previews +
    /// pre-T-703 fixtures. Read from `SettingsViewModel+CloudSync.swift`.
    let cloudSyncDependency: (any SettingsDependencies)?

    // MARK: - US-44 (T-739) — Profile section

    /// On-device user profile. `nil` in guest mode (the default).
    public internal(set) var profile: UserProfile?

    /// Keychain-backed profile store. `nil` for previews / snapshots.
    let profileStore: (any ProfileStoring)?

    /// DUT-565 — extra local-state clears (recent searches + comment moderation,
    /// which live in sibling feature packages) threaded into the Profile editor's
    /// account teardown. Injected by the App composition root that owns those
    /// stores; `nil` for previews / tests that don't reach the teardown buttons.
    let accountTeardownExtras: (@MainActor (Bool) async -> Void)?

    #if canImport(UIKit)
    /// Phase b (T-740) — Documents JPG photo store routed into the
    /// Profile row's avatar + the edit view's picker. `nil` for previews
    /// (see `SettingsViewModel+Profile.swift`). UIKit-gated. `internal(set)`
    /// so the convenience init in the extension file can assign it.
    var profilePhotoStore: (any ProfilePhotoStoring)?
    #endif

    /// Reload `profile` from the store. Fired by `ProfileEditView`'s
    /// `onProfileChanged` callback after a save / sign-out / delete.
    public func refreshProfile() async {
        guard let profileStore else { return }
        profile = await profileStore.load()
    }

    /// Authorization seam for the notifications toggle (US-42 / AC-42.1).
    /// The composition root injects a closure that calls
    /// `NotificationService.requestAuthorization()` (which wraps
    /// `UNUserNotificationCenter.current().requestAuthorization(...)`);
    /// it returns `true` iff the user grants. Defaults to a closure that
    /// reports "not granted" so previews / snapshot hosts / the L1 suite
    /// never touch `UserNotifications` — the view-model package builds on
    /// the macOS `swift test` slice where that framework is unavailable.
    /// `internal` so the `+Notifications.swift` setters reach it (T-750).
    let requestNotificationAuthorization: @MainActor () async -> Bool

    // MARK: - Persisted state

    /// AC-32.4. Reads + writes through ``defaults`` so a parallel write
    /// from another surface (e.g. a future Settings sync feature) is
    /// observed on the next read.
    public var useMetricUnits: Bool {
        get { defaults.bool(forKey: Self.useMetricUnitsKey) }
        set { defaults.set(newValue, forKey: Self.useMetricUnitsKey) }
    }

    /// AC-36.1. **DUT-430 — observable stored property** (was
    /// computed-over-`defaults`, which `@Observable` can't track → the
    /// deny-path revert only re-rendered because a nearby snackbar write
    /// happened to fire). Seeded from `defaults` in `init`, `didSet`-persisted.
    /// Defaults to false (absent key → off, the documented v1 starting state).
    public var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Self.notificationsEnabledKey) }
    }

    /// T-750 / CL-147 (DUT-56). The "When Someone Replies to My Comment"
    /// preference. **DUT-430 — observable stored property** (same fix as
    /// ``notificationsEnabled``). Seeded in `init`, `didSet`-persisted;
    /// defaults false (absent key → off). Written through the async
    /// ``setCommentReplyNotificationsEnabled(_:)`` so an enable requests
    /// system authorization, mirroring ``notificationsEnabled``.
    public var commentReplyNotificationsEnabled: Bool {
        didSet {
            defaults.set(commentReplyNotificationsEnabled, forKey: Self.commentReplyNotificationsEnabledKey)
        }
    }

    /// AC-36.2. **T-756 / CL-153 — observable stored property** (was
    /// computed-over-`defaults`, which `@Observable` can't track → the App
    /// Appearance picker label + sheet theme never updated live). Seeded
    /// from `defaults` in `init`, persisted via `didSet`.
    public var appearance: AppearancePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearancePreferenceKey) }
    }

    /// DUT-47. **T-756 / CL-153 — observable stored property** (moved here
    /// from the `+Temperature` extension — stored props can't live in
    /// extensions; the key stays there). Seeded in `init`, `didSet`-persisted.
    /// Recipe Detail still reads the persisted value via `@AppStorage`.
    public var temperaturePreference: TemperaturePreference {
        didSet { defaults.set(temperaturePreference.rawValue, forKey: Self.temperaturePreferenceKey) }
    }

    /// AC-36.3. Defaults to ``ShareFormatPreference/linkOnly``. Stays
    /// computed-over-defaults — no UI picker reads it (T-750 removed the
    /// row), so it doesn't need the T-756 observable treatment.
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

    /// Cached snapshot of the iCloud sync opt-in flag so `@Observable`
    /// emits a change when the view-model flips it. Public write path is
    /// ``setCloudSyncEnabled(_:)`` (T-759 / CL-156 — the toggle flips
    /// directly, no confirmation popup). Seeded from the dependency at init.
    public internal(set) var isCloudSyncEnabled: Bool

    /// Set when the user flips iCloud Sync *this session*. SwiftData
    /// builds its `ModelContainer` once per process; the flip only
    /// engages on the next cold launch. Surfacing this stops the
    /// "I toggled it and nothing synced" confusion. Not persisted.
    public internal(set) var cloudSyncPendingRelaunch = false

    /// Latest coarse sync status, pushed in from the App-target
    /// `NSPersistentCloudKitContainer` mirror observer (`CloudKitSyncDiagnostics`)
    /// via ``updateCloudSyncStatus(_:)`` (DUT-6, cause B). Defaults to
    /// ``CloudKitSyncStatus/off`` — the resting state before any mirror event,
    /// which renders as the reserved `"Idle"` placeholder so the row layout
    /// (and its L4 snapshot baseline) doesn't shift. `internal(set)` so only
    /// the update method (and tests) mutate it.
    public internal(set) var cloudSyncStatus: CloudKitSyncStatus = .off

    /// AC-41.7 status sublabel under the iCloud Sync row (DUT-6, cause B). A
    /// just-flipped toggle needs a relaunch before the live mirror status means
    /// anything (SwiftData builds the container once per process), so
    /// ``cloudSyncPendingRelaunch`` wins and the row reads "Relaunch DOD to
    /// apply". Otherwise it renders the mapped ``cloudSyncStatus`` — "Idle" /
    /// "Syncing…" / "Sync error" — defaulting to "Idle" until an event arrives.
    public var cloudSyncStatusText: String {
        cloudSyncPendingRelaunch
            ? CloudKitSyncStatus.relaunchPending.displayString
            : cloudSyncStatus.displayString
    }

    /// Push a fresh sync status in from the App-target mirror observer (DUT-6,
    /// cause B). Kept a tiny method (not a public setter) so the composition
    /// root has one clear seam to forward `CloudKitSyncDiagnostics` events
    /// through, and the L1 suite can pin the status → sublabel mapping.
    public func updateCloudSyncStatus(_ status: CloudKitSyncStatus) {
        cloudSyncStatus = status
    }

    // MARK: - Snackbar feedback (Clear Cache row)

    /// AC-36.4. Latest snackbar message from the Clear Cache action + the
    /// notification toggles' denied-authorization feedback. `nil` means no
    /// snackbar is showing. `internal(set)` (not `private(set)`) so the
    /// notification setters in `SettingsViewModel+Notifications.swift`
    /// surface their deny copy across the file_length split (T-750 / CL-147).
    public internal(set) var snackbarMessage: String?

    /// DUT-694 (PR-D) — bumped once per SUCCESSFUL cache clear so the Settings list
    /// can fire a `.success` sensory haptic (matching `FeedView`'s refresh haptic)
    /// WITHOUT also buzzing for the error copy or the notification-deny snackbars,
    /// which all share ``snackbarMessage``. A dedicated signal keeps the haptic
    /// tied to the one delightful "freed cache" moment.
    public internal(set) var cacheClearSuccessCount = 0

    public init(
        defaults: UserDefaults = .standard,
        dependencies: (any SettingsDependencies)? = nil,
        voicePreviewer: (any VoicePreviewing)? = nil,
        voiceLocale: Locale = .current,
        profileStore: (any ProfileStoring)? = nil,
        initialProfile: UserProfile? = nil,
        requestNotificationAuthorization: @escaping @MainActor () async -> Bool = { false },
        accountTeardownExtras: (@MainActor (Bool) async -> Void)? = nil
    ) {
        self.defaults = defaults
        // T-756 / CL-153 — seed the observable picker preferences (didSet
        // doesn't fire for these initial-in-init assignments).
        self.appearance = AppearancePreference.fromDefaults(defaults)
        self.temperaturePreference = TemperaturePreference.fromDefaults(defaults)
        // DUT-430 — seed the observable notification flags from defaults
        // (didSet doesn't fire for these initial-in-init assignments).
        self.notificationsEnabled = defaults.bool(forKey: Self.notificationsEnabledKey)
        self.commentReplyNotificationsEnabled = defaults.bool(forKey: Self.commentReplyNotificationsEnabledKey)
        self.voicePreviewer = voicePreviewer
        self.voiceLanguageCode = voiceLocale.language.languageCode?.identifier
        self.cloudSyncDependency = dependencies
        self.profileStore = profileStore
        self.accountTeardownExtras = accountTeardownExtras
        #if canImport(UIKit)
        self.profilePhotoStore = nil
        #endif
        self.profile = initialProfile
        self.requestNotificationAuthorization = requestNotificationAuthorization
        // US-41 AC-41.3 — seed the toggle from the canonical opt-in flag
        // (RecipeStore.cloudKitSyncOptInKey). Fall through to defaults
        // when no dependency is wired (previews / pre-T-703 fixtures).
        if let dependencies {
            self.isCloudSyncEnabled = dependencies.cloudSyncOptInValue()
        } else {
            self.isCloudSyncEnabled = defaults.bool(forKey: RecipeStore.cloudKitSyncOptInKey)
        }
        // US-44 (T-739) — lazy-warmup the profile when a store is wired
        // but no `initialProfile` was supplied (composition-root path).
        if profileStore != nil, initialProfile == nil {
            Task { [weak self] in await self?.refreshProfile() }
        }
    }

    // US-42 / AC-42.1 + T-750 / CL-147 — the notification toggle setters
    // (`setNotificationsEnabled` + `setCommentReplyNotificationsEnabled`)
    // live in `SettingsViewModel+Notifications.swift` to keep this file
    // inside the SwiftLint 400-line file_length cap (the same partitioning
    // rule the iCloud Sync + Voice + Temperature splits follow).

    // US-41 / AC-41.3 — iCloud Sync toggle actions live in
    // `SettingsViewModel+CloudSync.swift` to keep this file inside the
    // SwiftLint 400-line file_length cap (the same partitioning rule
    // RecipeStore + RecipeStore+Containers.swift follows in DODPersistence).

    // MARK: - Clear cached recipe images (AC-36.4)

    /// Calls through the supplied closure (routes to `RecipeStore.clearImageCache()`
    /// in production) and surfaces a snackbar with the freed-byte total formatted
    /// as MB; the zero-byte branch shows "Cache was already clear." so the tap is
    /// never a silent no-op. Keeps the view-model free of a hard `DODPersistence`
    /// dependency — the call-site supplies the store-backed closure; tests inject a
    /// stub to exercise the formatter and error path independently.
    public func clearImageCache(onClear: () async throws -> Int) async {
        do {
            let freedBytes = try await onClear()
            snackbarMessage = Self.cacheClearMessage(freedBytes: freedBytes)
            // DUT-694 (PR-D) — a clean completion earns a `.success` haptic via the
            // dedicated ``cacheClearSuccessCount`` trigger (see the Settings list).
            cacheClearSuccessCount += 1
        } catch {
            // Best-effort — the store actor's SwiftData writes are wrapped in
            // `try modelContext.save()`, which surfaces here on a persistence
            // failure. Surface a humane error rather than silently failing.
            snackbarMessage = "Couldn't clear cache. Try again."
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
        // DUT — a nonzero free below 0.1 MB rounds to "0.0 MB", which reads as
        // "freed nothing" and contradicts the `freedBytes > 0` zero-case above.
        guard megabytes >= 0.1 else {
            return "Freed less than 0.1 MB of cached images."
        }
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

// The iCloud Sync toggle action (`setCloudSyncEnabled`) lives in
// `SettingsViewModel+CloudSync.swift` (file_length split). The
// `AppearancePreference` + `ShareFormatPreference` value types live in
// `SettingsPreferences.swift` (same split, extended by T-721).

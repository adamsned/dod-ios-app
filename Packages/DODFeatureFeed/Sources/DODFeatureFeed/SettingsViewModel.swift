import DODFeatureProfile
import DODPersistence
import DODSupport
import Foundation
import Observation

/// State + persistence for the Settings page (US-32 skeleton, US-36 expansion,
/// US-41 iCloud Sync row, US-44 Profile section).
///
/// Persisted keys (`dod.settings.*` + `dod.cloudkit.*`):
/// - ``useMetricUnitsKey`` — Bool, AC-32.4.
/// - ``notificationsEnabledKey`` — Bool, AC-36.1 (US-42 / T-631 wires APNs).
/// - ``appearancePreferenceKey`` — String, AC-36.2 (RootView consumes).
/// - ``shareFormatPreferenceKey`` — String, AC-36.3.
/// - ``telemetryEnabledKey`` — Bool, AC-36.5 (TelemetryDeckTransport reads).
/// - `RecipeStore.cloudKitSyncOptInKey` — Bool, AC-41.3 (launch-time SoT
///   per DUT-6; routed through ``SettingsDependencies``).
///
/// US-44 (T-739) Profile section: the on-device ``profile`` and its
/// Keychain-backed ``profileStore`` are constructor-injected by the
/// composition root; ``refreshProfile()`` reloads after edit-view
/// dismiss.
///
/// `UserDefaults` is constructor-injected so the L1 unit suite can pass an
/// isolated `UserDefaults(suiteName:)` — pattern mirrors `RecentSearches`.
///
/// Spec trace: US-32 AC-32.4; US-36 AC-36.1..AC-36.8; US-41 AC-41.3, AC-41.4;
/// US-44 AC-44.1, AC-44.4.
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

    /// US-40 / AC-40.13 (T-722) — "I dismissed the download-a-better-voice
    /// tip" flag. Bool, defaults false (absent key → tip eligible). Once the
    /// user taps the tip's dismiss control this flips true and the nudge
    /// never re-shows, even if they keep only the compact voice installed —
    /// a nudge they've consciously waved off must not nag (CL-123). `V1`
    /// suffix mirrors the other canonical keys so a future schema change can
    /// migrate without colliding.
    public nonisolated static let downloadVoiceTipDismissedKey = "dod.settings.downloadVoiceTipDismissedV1"

    /// `internal` (not `private`) so the voice-section accessors in
    /// `SettingsViewModel+Voice.swift` can read the dismissal flag via the same
    /// store the rest of the view-model uses (the file_length split forces
    /// internal-but-not-private accessors, exactly as the iCloud Sync split did).
    let defaults: UserDefaults

    /// US-40 / AC-40.10..AC-40.11 (T-721). Backs the Cook Mode voice-gender
    /// picker. Built against the same injected ``defaults`` so the L1 suite
    /// drives it through an isolated `UserDefaults(suiteName:)`.
    private let voicePreferenceStore: VoicePreferenceStore

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

    /// US-40 / AC-40.10..AC-40.11 (T-721). The user's Cook Mode voice-gender
    /// preference. Reads + writes via ``VoicePreferenceStore`` (canonical key
    /// `dod.voice.preferredGenderV1`); defaults to ``VoiceGender/female`` when
    /// unset. `SystemSpeechSynthesizer` (recipe-detail read-aloud) reads the
    /// same store, so a change here is honored the next time Cook Mode
    /// resolves a voice.
    public var voiceGender: VoiceGender {
        get { voicePreferenceStore.preference().gender }
        set { voicePreferenceStore.setGender(newValue) }
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
    /// ``requestCloudSyncOptIn(_:)`` (AC-41.3 + CL-89 — confirmation
    /// alert is mandatory). Seeded from the dependency at init.
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

    /// State for the confirmation alert that fronts every toggle flip per
    /// AC-41.3 / CL-89. `nil` when no alert is showing; otherwise describes the
    /// direction (on → off vs off → on) so the view renders the right copy +
    /// button labels via ``cloudSyncConfirmationIsPresented``. Setter is
    /// `internal` so the action methods in `SettingsViewModel+CloudSync.swift`
    /// can mutate it while external callers stay locked out.
    public internal(set) var cloudSyncConfirmationRequest: CloudSyncConfirmationRequest?

    // MARK: - Snackbar feedback (Clear Cache row)

    /// AC-36.4. Latest snackbar message from the Clear Cache action.
    /// The view binds a `Snackbar` to this when non-nil and dismisses
    /// it via ``dismissSnackbar()``. `nil` means no snackbar is showing.
    public private(set) var snackbarMessage: String?

    public init(
        defaults: UserDefaults = .standard,
        dependencies: (any SettingsDependencies)? = nil,
        voicePreviewer: (any VoicePreviewing)? = nil,
        voiceLocale: Locale = .current,
        profileStore: (any ProfileStoring)? = nil,
        initialProfile: UserProfile? = nil,
        requestNotificationAuthorization: @escaping @MainActor () async -> Bool = { false }
    ) {
        self.defaults = defaults
        self.voicePreferenceStore = VoicePreferenceStore(defaults: defaults)
        self.voicePreviewer = voicePreviewer
        self.voiceLanguageCode = voiceLocale.language.languageCode?.identifier
        self.cloudSyncDependency = dependencies
        self.profileStore = profileStore
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

// `CloudSyncConfirmationRequest` lives in `SettingsViewModel+CloudSync.swift`
// alongside the iCloud Sync action methods (file_length split). The
// `AppearancePreference` + `ShareFormatPreference` value types live in
// `SettingsPreferences.swift` (same split, extended by T-721).

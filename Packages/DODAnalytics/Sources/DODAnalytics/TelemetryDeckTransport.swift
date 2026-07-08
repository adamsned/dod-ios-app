import Foundation
import TelemetryDeck

/// Production telemetry transport, backed by TelemetryDeck.
///
/// **TelemetryDeck is imported ONLY in this file** (constitution §9, plan §6).
/// Feature modules talk to ``Telemetry`` / ``AnalyticsEvent`` and never see
/// the upstream SDK. Replacing the provider is a one-file change.
///
/// Calling `TelemetryDeck.signal()` before `initialize(config:)` is a fatal
/// error in the SDK — so the transport lazily initializes the SDK on the first
/// *allowed* `send(_:)` (never at `configure(appID:)`; see DUT-241) and only
/// ever signals after that init.
///
/// **Privacy opt-out gate (US-36 / AC-36.5 / AC-36.6).** Every `send(_:)`
/// call reads the user's "Share anonymous usage data" preference from
/// `UserDefaults` (key ``telemetryEnabledKey``) and short-circuits before
/// the SDK call when the flag is false. The default-ON behavior is
/// `object(forKey:) as? Bool ?? true` so an absent key honors the
/// constitution §9 opt-out posture (telemetry on by default; user can
/// disable it from Settings → "Share anonymous usage data"). The gate
/// lives in the production transport — not in the ``Telemetry`` facade —
/// so ``RecordingTelemetryTransport`` (the test fixture) continues to
/// capture every event for L1 assertions; only the upstream wire path is
/// gated.
public final class TelemetryDeckTransport: TelemetryTransport, @unchecked Sendable {

    /// `UserDefaults` key for the privacy toggle. Authoritative copy
    /// lives in `SettingsViewModel.telemetryEnabledKey` (DODFeatureFeed);
    /// duplicated here as a literal string so this package doesn't have
    /// to depend on DODFeatureFeed (which would invert the dependency
    /// graph — Feature packages depend on Analytics, not vice versa).
    /// Both surfaces use the same literal `"dod.settings.telemetryEnabled"`.
    ///
    /// Spec trace: US-36 AC-36.5 / AC-36.6 — privacy opt-out gate.
    public static let telemetryEnabledKey = "dod.settings.telemetryEnabled"

    private let lock = NSLock()
    private var appID: String?
    /// Whether the upstream SDK has been initialized. DUT-241: this only flips
    /// true on the first *allowed* `send(_:)` — never at configure-time — so an
    /// opted-out user never triggers SDK initialization.
    private var initialized = false
    private let defaults: UserDefaults
    private let initializeSDK: (String) -> Void
    private let emitSignal: (String, [String: String]) -> Void
    private let purgeSDK: () -> Void

    /// Per-app constant salt for the pseudonymous identifier (DUT-669).
    ///
    /// TelemetryDeck salts the device identifier before hashing it into a
    /// pseudonymous id. When `salt` is left unset the SDK falls back to
    /// `salt=""`, which makes the pseudonym an *unsalted* SHA-256 of the
    /// device identifier — trivially precomputable / cross-app correlatable.
    /// A fixed non-empty per-app constant keeps the pseudonym stable across
    /// runs (so distinct-user counts still work) while removing the empty
    /// default. It is intentionally hard-coded (not user- or install-derived)
    /// so it never changes and never itself becomes tracked data.
    ///
    /// Spec trace: DUT-669 — salt the pseudonymous id.
    static let pseudonymSalt = "dod.telemetry.pseudonym.salt.v1"

    /// `defaults` defaults to `UserDefaults.standard` in production. The L1 unit
    /// tests inject an isolated suite via `UserDefaults(suiteName:)` so they can
    /// pin the gate's behavior without polluting the standard defaults.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.initializeSDK = { appID in
            // DUT-669: pass a fixed non-empty `salt` so the pseudonymous id is
            // no longer an unsalted SHA-256 of the device identifier. `salt` is
            // a `let` on `Config` — it can only be set through the initializer.
            let config = TelemetryDeck.Config(appID: appID, salt: Self.pseudonymSalt)
            // DUT-241: stop the SDK from emitting its OWN session/identity
            // signal (TelemetryDeck.Session.started + the salted identifier)
            // outside the app's gated allowlist.
            config.sendNewSessionBeganSignal = false
            TelemetryDeck.initialize(config: config)
        }
        self.emitSignal = { name, parameters in
            TelemetryDeck.signal(name, parameters: parameters)
        }
        // DUT-665: `terminate()` deinitializes the current `TelemetryManager`,
        // which drops its `SignalManager` and cancels the background flush
        // timer — the only public SDK API that actually stops the SDK's own
        // on-disk cache + background dispatch. See `send(_:)` for the opt-out
        // transition that invokes it.
        self.purgeSDK = { TelemetryDeck.terminate() }
    }

    /// Test seam (DUT-241 / DUT-665): inject fakes for SDK init + signal + purge
    /// so L1 tests can assert the privacy gate prevents BOTH initialization and
    /// emission, and that opting out tears the SDK down — without linking the
    /// real TelemetryDeck wire path.
    init(
        defaults: UserDefaults,
        initializeSDK: @escaping (String) -> Void,
        emitSignal: @escaping (String, [String: String]) -> Void,
        purgeSDK: @escaping () -> Void = {}
    ) {
        self.defaults = defaults
        self.initializeSDK = initializeSDK
        self.emitSignal = emitSignal
        self.purgeSDK = purgeSDK
    }

    /// Store the upstream app ID. DUT-241: this no longer initializes the SDK —
    /// initialization is deferred to the first allowed `send(_:)`, so an
    /// opted-out user never initializes TelemetryDeck at all.
    public func configure(appID: String) {
        lock.lock()
        self.appID = appID
        lock.unlock()
    }

    public func send(_ event: AnalyticsEvent) {
        // AC-36.5 / AC-36.6 / DUT-241: the privacy gate runs BEFORE any SDK
        // work. When "Share anonymous usage data" is OFF the TelemetryDeck SDK
        // is never initialized — no Session.started, no pseudonymous
        // identifier, nothing dispatched. The gate is re-read at every send so
        // flipping the toggle takes effect immediately; the SDK is lazily
        // initialized on the first ALLOWED event (so enabling it mid-session
        // works without a relaunch).
        // DUT-665: the per-send gate below blocks FUTURE sends, but the
        // already-initialized SDK keeps its own on-disk signal cache and a
        // background flush timer — so signals queued while telemetry was ON
        // could still leave the device after the user opts OUT. On the opt-out
        // transition (disabled AND the SDK was previously initialized) we
        // additionally tear the SDK down (`purgeSDK` -> `TelemetryDeck.terminate()`),
        // which deinitializes the manager and cancels its background flush, and
        // reset `initialized` so a later opt-in re-initializes cleanly.
        guard isTelemetryEnabled() else {
            purgeIfInitialized()
            return
        }
        lock.lock()
        if !initialized {
            guard let appID else {
                lock.unlock()
                return
            }
            initializeSDK(appID)
            initialized = true
        }
        // DUT-704: emit while still holding `lock` so a concurrent opt-out
        // `purgeIfInitialized()` (which terminates the SDK under the same lock)
        // cannot interleave between the initialized check and the emit — no
        // signal-after-terminate crash, and no signal leaves after opt-out.
        emitSignal(event.name, event.payload)
        lock.unlock()
    }

    /// DUT-665: on an opt-out where the SDK is already live, stop and deinit it
    /// so its cached signals + background flush can't send after opt-out. Runs
    /// under `lock` and only purges once per initialization so repeated
    /// opted-out sends don't re-terminate an already-torn-down client.
    private func purgeIfInitialized() {
        lock.lock()
        guard initialized else {
            lock.unlock()
            return
        }
        initialized = false
        // DUT-704: tear the SDK down while still holding `lock` so terminate()
        // is mutually exclusive with `send(_:)`'s emit — the two can never overlap.
        purgeSDK()
        lock.unlock()
    }

    /// Read the user's privacy toggle, defaulting to `true` when absent.
    /// Exposed as a method (not a property) so the read happens at call-time —
    /// a parallel mutation from `SettingsViewModel` lands here on the next
    /// event without any observation plumbing.
    private func isTelemetryEnabled() -> Bool {
        (defaults.object(forKey: Self.telemetryEnabledKey) as? Bool) ?? true
    }
}

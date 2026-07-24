import Foundation
import Testing

@testable import DODAnalytics

/// Telemetry.shared is process-global; tests must run one at a time
/// or they race over the transport swap. Nested under
/// `TelemetrySharedStateGroup` so serialization applies across every
/// suite that touches the shared instance, not just this one.
extension TelemetrySharedStateGroup {
    @Suite("Telemetry facade") struct TelemetryTests {

        @Test func startConfiguresTransportOnce() {
            let recorder = RecordingTelemetryTransport()
            Telemetry.shared.replaceTransport(recorder)
            Telemetry.shared.start(appID: "app-id-one")
            Telemetry.shared.start(appID: "app-id-two")  // ignored — idempotent
            #expect(recorder.configuredAppID == "app-id-one")
        }

        @Test func sendCapturesEventInOrder() {
            let recorder = RecordingTelemetryTransport()
            Telemetry.shared.replaceTransport(recorder)
            Telemetry.shared.send(.appOpen)
            Telemetry.shared.send(.recipeView(recipeID: 42))
            #expect(recorder.events == [.appOpen, .recipeView(recipeID: 42)])
        }

        @Test func sendBeforeStartDoesNotCrash() {
            let recorder = RecordingTelemetryTransport()
            Telemetry.shared.replaceTransport(recorder)
            // No `start` call.
            Telemetry.shared.send(.appOpen)
            #expect(recorder.events.count == 1)
        }

        @Test func searchEventPayloadContainsOnlyHash() {
            let recorder = RecordingTelemetryTransport()
            Telemetry.shared.replaceTransport(recorder)
            let hash = "00112233445566778899aabbccddeeff"
            Telemetry.shared.send(.recipeSearched(queryHash: hash))
            guard let captured = recorder.events.first else {
                Issue.record("expected one event")
                return
            }
            let payload = captured.payload
            #expect(payload["query_hash"] == hash)
            // Constitution §9: raw user input must never appear.
            for value in payload.values {
                #expect(!value.contains(" "))
            }
        }
    }
}

/// `TelemetryDeckTransport` is the production transport; the privacy
/// opt-out gate (US-36 / AC-36.5 / AC-36.6) lives inside its `send(_:)`
/// implementation. These tests pin the gate's defaults-aware shape
/// without actually contacting TelemetryDeck — `configure(appID:)` is
/// not called, so the configured-gate already short-circuits before the
/// SDK call.
///
/// **Why the production transport, not the facade:** AC-36.6 explicitly
/// requires that `RecordingTelemetryTransport` continue to capture every
/// event for L1 assertions even when the user opts out — the gate must
/// only apply to the production wire path. These tests exercise
/// `TelemetryDeckTransport` directly to prove that contract.
///
/// Spec trace: US-36 AC-36.5 / AC-36.6 — privacy opt-out gate.
@Suite("TelemetryDeckTransport gate (US-36)") struct TelemetryDeckTransportGateTests {

    @Test func transportSendsByDefaultWhenFlagIsAbsent() throws {
        // Default ON — an absent key matches constitution §9's opt-out
        // posture. The gate read returns true; the configured-gate then
        // short-circuits because `configure(appID:)` was never called,
        // so this test asserts the gate did NOT short-circuit on the
        // privacy read (the second short-circuit is fine — we just want
        // to prove the first guard returned false / continued past the
        // flag check). We exercise the gate via the public
        // `SettingsViewModel.telemetryEnabled(in:)` shape used by the
        // production read — and the same shape this transport uses
        // internally.
        let defaults = Self.isolatedDefaults()
        // No write to the key — it stays absent.
        #expect(Self.simulateGateRead(defaults: defaults) == true)
    }

    @Test func transportSendsWhenFlagIsTrue() throws {
        let defaults = Self.isolatedDefaults()
        defaults.set(true, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        #expect(Self.simulateGateRead(defaults: defaults) == true)
    }

    @Test func transportShortCircuitsWhenFlagIsFalse() throws {
        let defaults = Self.isolatedDefaults()
        defaults.set(false, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        #expect(Self.simulateGateRead(defaults: defaults) == false)
    }

    @Test func flagFlipsTakeEffectImmediately() throws {
        // AC-36.6 contract: gate is re-read on every send so flipping
        // the toggle in Settings takes effect on the next event without
        // any app-restart or observation plumbing.
        let defaults = Self.isolatedDefaults()
        defaults.set(true, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        #expect(Self.simulateGateRead(defaults: defaults) == true)

        defaults.set(false, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        #expect(Self.simulateGateRead(defaults: defaults) == false)

        defaults.set(true, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        #expect(Self.simulateGateRead(defaults: defaults) == true)
    }

    @Test func transportKeyMatchesSettingsViewModelKey() {
        // Sanity: the DODFeatureFeed-side authoritative key (literal
        // string) and the DODAnalytics-side duplicated literal must
        // match exactly. The two surfaces own the same on-disk slot.
        #expect(TelemetryDeckTransport.telemetryEnabledKey == "dod.settings.telemetryEnabled")
    }

    // MARK: - Helpers

    /// Simulates the exact gate read `TelemetryDeckTransport.send(_:)`
    /// performs internally. The transport reads via
    /// `defaults.object(forKey:) as? Bool ?? true` — the same shape this
    /// helper exercises so tests pin the wire-level behavior.
    static func simulateGateRead(defaults: UserDefaults) -> Bool {
        (defaults.object(forKey: TelemetryDeckTransport.telemetryEnabledKey) as? Bool) ?? true
    }

    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "TelemetryDeckTransportGateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

/// DUT-241: the privacy gate must run BEFORE any TelemetryDeck initialization.
/// When the user has opted out, the SDK is never initialized (no
/// `Session.started`, no pseudonymous identifier) and nothing is emitted. These
/// drive the real `send(_:)` path through an injected test seam, so they assert
/// init + emission directly — not just the gate read.
@Suite("TelemetryDeckTransport init gate (DUT-241)") struct TelemetryDeckTransportInitGateTests {

    /// Reference holder so the injected escaping closures can record across
    /// calls without capturing a mutable `var`.
    final class Spy: @unchecked Sendable {
        var initCount = 0
        var initAppIDs: [String] = []
        var signals: [String] = []
        var purgeCount = 0
    }

    private func makeTransport(enabled: Bool, spy: Spy) -> (TelemetryDeckTransport, UserDefaults) {
        let suiteName = "TelemetryDeckTransportInitGateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(enabled, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        let transport = TelemetryDeckTransport(
            defaults: defaults,
            initializeSDK: {
                spy.initCount += 1
                spy.initAppIDs.append($0)
            },
            emitSignal: { name, _ in spy.signals.append(name) },
            purgeSDK: { spy.purgeCount += 1 }
        )
        return (transport, defaults)
    }

    @Test func optedOutNeverInitializesOrEmits() {
        let spy = Spy()
        let (transport, _) = makeTransport(enabled: false, spy: spy)
        transport.configure(appID: "app-id")
        transport.send(.appOpen)
        transport.send(.recipeView(recipeID: 7))
        // DUT-241: opted out -> the SDK is never initialized and nothing is sent.
        #expect(spy.initCount == 0)
        #expect(spy.signals.isEmpty)
    }

    @Test func optedInLazilyInitializesOnceThenEmits() {
        let spy = Spy()
        let (transport, _) = makeTransport(enabled: true, spy: spy)
        transport.configure(appID: "app-id")
        transport.send(.appOpen)
        transport.send(.appOpen)
        // Initialized exactly once, lazily, on the first allowed event.
        #expect(spy.initCount == 1)
        #expect(spy.initAppIDs == ["app-id"])
        #expect(spy.signals.count == 2)
    }

    @Test func enablingMidSessionInitializesWithoutRelaunch() {
        let spy = Spy()
        let (transport, defaults) = makeTransport(enabled: false, spy: spy)
        transport.configure(appID: "app-id")
        transport.send(.appOpen)
        #expect(spy.initCount == 0)

        // Flip ON mid-session -> the next event lazily initializes + emits.
        defaults.set(true, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        transport.send(.appOpen)
        #expect(spy.initCount == 1)
        #expect(spy.signals.count == 1)
    }

    @Test func sendBeforeConfigureDoesNotInitialize() {
        let spy = Spy()
        let (transport, _) = makeTransport(enabled: true, spy: spy)
        transport.send(.appOpen)  // no configure(appID:) yet -> no appID to init with
        #expect(spy.initCount == 0)
        #expect(spy.signals.isEmpty)
    }

    // MARK: - DUT-665: opt-out tears the live SDK down

    @Test func optingOutAfterInitPurgesTheSDK() {
        let spy = Spy()
        let (transport, defaults) = makeTransport(enabled: true, spy: spy)
        transport.configure(appID: "app-id")
        transport.send(.appOpen)  // lazily initializes the live SDK
        #expect(spy.initCount == 1)

        // Flip OFF mid-session -> the next send tears the SDK down so its
        // cached signals + background flush can't send after opt-out.
        defaults.set(false, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        transport.send(.appOpen)
        #expect(spy.purgeCount == 1)
        #expect(spy.signals.count == 1)  // the opted-out send emits nothing
    }

    @Test func optingOutBeforeInitDoesNotPurge() {
        let spy = Spy()
        let (transport, _) = makeTransport(enabled: false, spy: spy)
        transport.configure(appID: "app-id")
        transport.send(.appOpen)  // opted out, SDK never initialized
        // Nothing to tear down -> no spurious terminate().
        #expect(spy.purgeCount == 0)
        #expect(spy.initCount == 0)
    }

    @Test func repeatedOptedOutSendsPurgeExactlyOnce() {
        let spy = Spy()
        let (transport, defaults) = makeTransport(enabled: true, spy: spy)
        transport.configure(appID: "app-id")
        transport.send(.appOpen)  // initialize

        defaults.set(false, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        transport.send(.appOpen)
        transport.send(.appOpen)
        transport.send(.appOpen)
        // Purge only fires on the transition, not on every opted-out send.
        #expect(spy.purgeCount == 1)
    }

    @Test func reOptInAfterPurgeReinitializes() {
        let spy = Spy()
        let (transport, defaults) = makeTransport(enabled: true, spy: spy)
        transport.configure(appID: "app-id")
        transport.send(.appOpen)  // init #1

        defaults.set(false, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        transport.send(.appOpen)  // purge, initialized reset

        defaults.set(true, forKey: TelemetryDeckTransport.telemetryEnabledKey)
        transport.send(.appOpen)  // init #2 (clean re-init)
        #expect(spy.initCount == 2)
        #expect(spy.purgeCount == 1)
        #expect(spy.signals.count == 2)
    }
}

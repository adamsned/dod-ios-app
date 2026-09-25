import Foundation

/// `Telemetry.shared` is process-global. Both ``TelemetryTests`` and
/// ``TelemetryMultiTransportTests`` swap its transport, and swift-testing runs
/// the two suites in PARALLEL with each other — each suite's own `.serialized`
/// trait only orders the tests *within* that suite, not across suites. So a
/// test in one suite could `replaceTransport(...)` out from under a test in the
/// other mid-body, dropping events (e.g. `sendCapturesEventInOrder` capturing
/// only `[.appOpen]` instead of `[.appOpen, .recipeView]`) — an intermittent L1
/// flake that a CI retry can't clear because it's an assertion failure, not a
/// teardown crash.
///
/// Isolating both suites to this single global actor makes every telemetry test
/// run on one executor, so no two ever overlap — deterministic, and async-safe
/// (unlike a bare lock held across a suspension point).
@globalActor
actor TelemetryTestActor {
    static let shared = TelemetryTestActor()
}

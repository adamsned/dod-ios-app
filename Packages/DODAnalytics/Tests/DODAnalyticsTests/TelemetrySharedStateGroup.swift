import Testing

/// Namespace-only parent suite for every test suite that mutates the
/// process-global `Telemetry.shared` singleton.
///
/// `TelemetryTests` and `TelemetryMultiTransportTests` each carried their
/// own `.serialized` trait, and each file's doc comment correctly noted
/// that its own tests must not interleave — but `.serialized` only
/// serializes a suite's own children. swift-testing still parallelizes
/// *across* independently-declared suites, so the two suites raced each
/// other over the same shared instance (flaky CI failures on
/// `multipleAdditionalTransportsAllReceiveEventsInOrder`, e.g. PR #765,
/// #789, #793 — confirmed by reproducing the race locally with an
/// injected delay between `start` and `send`).
///
/// Nesting both suites here and serializing the *parent* fixes it:
/// `.serialized` cascades to the whole subtree, so both suites' tests
/// now run one at a time, in some order, never concurrently with each
/// other. Do not add a suite here unless it also touches
/// `Telemetry.shared` — nesting anything else would slow it down for no
/// reason.
@Suite("Telemetry.shared (serialized group)", .serialized)
enum TelemetrySharedStateGroup {}

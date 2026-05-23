# Performance Audit — v1.0

**Status:** Cluster I (T-170, T-171, T-172) — XCTest scaffold landed; Instruments work pending in-simulator session.

**Governs:** constitution §8 (budgets), spec CC-7.

## Budgets (from constitution)

| Metric | Budget | Measurement device |
|---|---|---|
| Cold launch → first interactive frame | < 1.5s | iPhone 13 baseline |
| Recipe list scroll | 60fps sustained, 0 dropped frames | iPhone 13 baseline |
| Recipe detail open (cached) | < 300ms | iPhone 13 baseline |
| Recipe detail open (fetched) | < 1.5s | iPhone 13 baseline |
| App install size | < 30 MB | App Store Connect "App Thinning Size Report" |

## What's been done in code

### Cold-launch hygiene (T-170)

- `AppDependencies.init()` does only sync work: constructs lightweight wrappers around URLSession, NWPathMonitor, SwiftData ModelContainer.
- `bootstrap()` (the async setup) is called from `.task` on RootView — it doesn't block first frame.
- Telemetry init is conditional on `Info.plist` presence; failing without an app ID does **not** block launch.
- No third-party SDK initializes synchronously at @main (TelemetryDeck lazily configures inside `Telemetry.start`).

### Scroll hygiene (T-171)

- All list screens use `LazyVGrid` so off-screen rows aren't built.
- `RecipeCard` uses `AsyncImage` with disk caching delegated to the system; no per-row Decoders or large in-memory blobs.
- `LoadingSkeleton` shimmer runs on the main actor but with `withAnimation(.repeatForever)` — system handles it on the render server.

### Parser perf (T-172)

- `JSONLDRecipeParser` uses `JSONSerialization` (faster than Codable for unknown shapes) + a single-pass cursor scan for `<script>` block extraction. No HTML parser dep.
- `PerformanceTests.testParseCakeFixturePerformance` measures parsing the largest real fixture 10 times. Baseline gets locked on first CI run; XCTest fails the build if a future change drifts > 10%.

## What still requires Instruments + a real device

These are in-simulator or on-device tasks — cannot be done from source code alone:

- [ ] **Cold-launch trace.** Run **Time Profiler** with the **App Launch** template against the Debug build on an iPhone 13 (or closest simulator approximation). Walk the call tree for any work over 50ms in `application(_:didFinishLaunchingWithOptions:)` or `DODApp.init`. Top-3 contributors should be eliminated or deferred.
- [ ] **List-scroll trace.** Run the **Animation Hitches** template on the Feed scrolling through 100 rows. Any hitch ≥ 100ms must be investigated — almost always an image decode on the main thread.
- [ ] **Memory growth.** Run **Allocations** for 5 minutes of normal use (browse → open → save → back → repeat). Heap growth should plateau, not grow unboundedly. Watch for `CachedImage` rows retained beyond their visible lifetime.
- [ ] **Network usage.** Settings → Developer → Network Link Conditioner → "3G" — verify the offline banner and skeletons behave gracefully at slow speeds.
- [ ] **Install size.** Upload to App Store Connect → TestFlight → look at the **App Thinning Size Report** for each device. The 30 MB budget is *post-thinning*, so the raw .ipa can be larger.

## Test gate for CI

CI runs `JSONLDParserPerformanceTests` as part of `swift test` in the DODNetworking package matrix. The first run establishes the baseline; subsequent runs fail if performance drifts > 10% from baseline.

To extend perf gating to view models (e.g. measure feed load time): add similar XCTest files under each feature's `Tests/` directory, using `measure { }` blocks. View-model tests are already mostly in Swift Testing and run sub-millisecond, so the value is small until we add a real device CI job.

## When to revisit

- Before every TestFlight build.
- After any cluster-level change (e.g. adding CloudKit sync in v2 will materially change cold-launch).
- If telemetry shows the average recipe-view duration spiking — could mean the network path got slow or the parser regressed.

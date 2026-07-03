import DODNetworking
import Foundation

// T-610 — hermetic E2E network wiring, factored out of `AppDependencies.init`
// for the file_length cap. See `E2EStubHTTPClient` / `E2EFixtures`.
extension AppDependencies {

    /// True when the host was launched by the L5 `DODAppE2ETests` scheme
    /// (`-DOD_E2E_MODE=1`). Read directly from `ProcessInfo` here rather than via
    /// `DODEnvironment.isE2EMode`, because `DODApp.applyTestLaunchOverrides()`
    /// sets that flag only AFTER the `@State` `AppDependencies()` default is
    /// constructed — too late for this init.
    static func isE2ELaunch() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-DOD_E2E_MODE=1")
            || ProcessInfo.processInfo.environment["DOD_E2E_MODE"] == "1"
    }

    /// Use the clean in-memory store: the L3 `-DODUseInMemoryStore` isolation
    /// hook OR hermetic E2E — both want a store that starts empty and never
    /// persists across UI-test runs on a shared simulator.
    static func useInMemoryStore() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-DODUseInMemoryStore") || isE2ELaunch()
    }

    /// The `HTTPClient` every network client shares: the canned, deterministic
    /// ``E2EStubHTTPClient`` in hermetic mode, else the real URLSession-backed
    /// ``URLSessionHTTPClient``.
    static func makeHTTPClient() -> HTTPClient {
        isE2ELaunch() ? E2EStubHTTPClient() : URLSessionHTTPClient()
    }
}

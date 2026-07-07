import Foundation
import Testing

@testable import DODNetworking

/// DUT-522: after ``NetworkMonitor/start()`` runs, ``isOnline`` must be seeded
/// from the real path status — not the pre-start `true` default that was
/// previously only overwritten on the first async `pathUpdateHandler` hop (so
/// `await isOnline` in the launch window could mis-read a genuinely offline
/// device as online).
///
/// Hardened to be deterministic: the original test raced two live
/// `NWPathMonitor`s against the CI host's actual connectivity and flaked when
/// they resolved out of step. Instead we inject a known seed status via
/// `NetworkMonitor(seedStatusOverride:)` and assert `start()` seeds `isOnline`
/// to exactly that — proving the seed is derived from the path (both online and
/// offline) without ever reading the host.
@Suite("NetworkMonitor seed (DUT-522)")
struct NetworkMonitorSeedTests {

    @Test func startSeedsOnlineFromPathStatus() async {
        let monitor = NetworkMonitor(seedStatusOverride: { true })
        await monitor.start()
        #expect(await monitor.isOnline == true)
    }

    @Test func startSeedsOfflineFromPathStatus() async {
        // The regression guard: a genuinely-offline path must NOT return the
        // pre-start `true` default. With the seed forced false, `start()` must
        // leave `isOnline == false`.
        let monitor = NetworkMonitor(seedStatusOverride: { false })
        await monitor.start()
        #expect(await monitor.isOnline == false)
    }

    @Test func startIsIdempotent() async {
        let monitor = NetworkMonitor(seedStatusOverride: { false })
        await monitor.start()
        let first = await monitor.isOnline
        await monitor.start()
        let second = await monitor.isOnline
        #expect(first == second)
    }
}

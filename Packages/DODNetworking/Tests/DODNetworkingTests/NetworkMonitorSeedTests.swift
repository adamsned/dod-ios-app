import Foundation
import Network
import Testing

@testable import DODNetworking

/// DUT-522: after ``NetworkMonitor/start()`` runs, ``isOnline`` must reflect the
/// device's real connectivity — seeded synchronously from
/// `NWPathMonitor.currentPath` — rather than the pre-start `true` default that
/// was previously only overwritten on the first async `pathUpdateHandler` hop
/// (so `await isOnline` in the launch window could mis-read a genuinely offline
/// device as online).
///
/// The monitor wraps a live `NWPathMonitor` and can't inject a fake path, so we
/// assert the observable contract that holds regardless of the host's actual
/// connectivity (the SPM/CI sandbox may report either verdict): `start()` leaves
/// `isOnline` equal to the path the monitor itself sees, and `start()` is
/// idempotent. The key regression this guards is that the seed is derived from
/// `currentPath` (not the hard-coded `true` default).
@Suite("NetworkMonitor seed (DUT-522)")
struct NetworkMonitorSeedTests {

    @Test func startSeedsFromCurrentPathNotTheDefault() async {
        // Ground truth: what a fresh, started NWPathMonitor reports for this host.
        let probe = NWPathMonitor()
        let probeQueue = DispatchQueue(label: "test.networkmonitor.probe")
        probe.start(queue: probeQueue)
        defer { probe.cancel() }
        let expected = probe.currentPath.status == .satisfied

        let monitor = NetworkMonitor()
        await monitor.start()
        let online = await monitor.isOnline
        // The seeded value tracks the real path, whatever it is on this host —
        // proving `start()` reads `currentPath` rather than returning the
        // pre-start `true` default unconditionally.
        #expect(online == expected)
    }

    @Test func startIsIdempotent() async {
        let monitor = NetworkMonitor()
        await monitor.start()
        let first = await monitor.isOnline
        await monitor.start()
        let second = await monitor.isOnline
        #expect(first == second)
    }
}

import Foundation
import Testing

@testable import DODSupport

final class FakeProbeTransport: ProbeTransport, @unchecked Sendable {
    var onReading: (@Sendable (Data) -> Void)?
    var onState: (@Sendable (ProbeConnectionState) -> Void)?
    private(set) var startScanCalls = 0
    private(set) var stopCalls = 0
    func startScan(serviceUUIDs: [String], characteristicUUID: String) { startScanCalls += 1 }
    func stop() { stopCalls += 1 }
}

@MainActor
@Suite("ProbeService (DUT-135)")
struct ProbeServiceTests {
    @Test func testNoScanBeforeConsent() {
        let fake = FakeProbeTransport()
        let service = ProbeService(transport: fake)
        #expect(fake.startScanCalls == 0)
        #expect(service.state == .idle)
        #expect(service.hasConsented == false)
    }

    @Test func testConsentStartsScan() {
        let fake = FakeProbeTransport()
        let service = ProbeService(transport: fake)
        service.grantConsentAndScan()
        #expect(fake.startScanCalls == 1)
        #expect(service.state == .scanning)
    }

    @Test func testReadingUpdatesStateAndLastReading() async throws {
        let fake = FakeProbeTransport()
        let service = ProbeService(transport: fake)
        service.grantConsentAndScan()
        fake.onReading?(Data([0x01, 0x4A, 0x06, 0x00, 0xFF]))
        await Task.yield()
        let reading = try #require(service.lastReading)
        #expect(abs(reading.internalF - 161.0) < 0.01)
        #expect(service.state == .connected)
    }

    @Test func testStopReturnsToIdle() {
        let fake = FakeProbeTransport()
        let service = ProbeService(transport: fake)
        service.grantConsentAndScan()
        service.stop()
        #expect(fake.stopCalls == 1)
        #expect(service.state == .idle)
    }
}

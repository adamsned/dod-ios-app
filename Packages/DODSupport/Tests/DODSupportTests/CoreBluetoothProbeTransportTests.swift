#if canImport(CoreBluetooth)
import CoreBluetooth
import Testing

@testable import DODSupport

@Suite("CoreBluetoothProbeTransport (DUT-135)")
struct CoreBluetoothProbeTransportTests {
    @Test func testPoweredOffAndUnauthorizedMapToUnauthorized() {
        #expect(CoreBluetoothProbeTransport.connectionState(for: .poweredOff) == .unauthorized)
        #expect(CoreBluetoothProbeTransport.connectionState(for: .unauthorized) == .unauthorized)
    }

    @Test func testPoweredOnMapsToScanningAndUnknownIsIgnored() {
        #expect(CoreBluetoothProbeTransport.connectionState(for: .poweredOn) == .scanning)
        #expect(CoreBluetoothProbeTransport.connectionState(for: .unknown) == nil)
    }

    @Test func testInitDoesNotCreateManagerOrCallback() {
        let transport = CoreBluetoothProbeTransport()
        #expect(transport.onReading == nil)
        #expect(transport.onState == nil)
    }
}
#endif

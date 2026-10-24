import Foundation
import Testing

@testable import DODSupport

@Suite("ProbeAdapter (DUT-135)")
struct ProbeAdapterTests {

    @Test func testShortDataReturnsNil() {
        let adapter: any ProbeAdapter = GenericGATTProbeAdapter()
        #expect(adapter.decode(Data([0x00, 0x6E, 0x00]), now: Date()) == nil)
    }

    @Test func testUUIDs() {
        let adapter = GenericGATTProbeAdapter()
        #expect(adapter.serviceUUIDs == ["1809"])
        #expect(adapter.temperatureCharacteristicUUID == "2A1C")
    }
}

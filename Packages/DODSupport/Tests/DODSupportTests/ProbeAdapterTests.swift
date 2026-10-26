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

    @Test func testCelsiusDecodesToFahrenheit() throws {
        // mantissa 110, exponent -1 => 11.0 C => 51.8 F
        let adapter = GenericGATTProbeAdapter()
        let reading = try #require(adapter.decode(Data([0x00, 0x6E, 0x00, 0x00, 0xFF]), now: Date()))
        #expect(abs(reading.internalF - 51.8) < 0.01)
    }
}

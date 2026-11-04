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

    @Test func testFahrenheitFlagIsNotConverted() throws {
        // flags bit0 = 1; mantissa 0x00064A = 1610, exponent -1 => 161.0 F
        let adapter = GenericGATTProbeAdapter()
        let reading = try #require(adapter.decode(Data([0x01, 0x4A, 0x06, 0x00, 0xFF]), now: Date()))
        #expect(abs(reading.internalF - 161.0) < 0.01)
    }

    @Test func testTimestampIsPassedThrough() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let adapter = GenericGATTProbeAdapter()
        let reading = try #require(adapter.decode(Data([0x00, 0x6E, 0x00, 0x00, 0xFF]), now: now))
        #expect(reading.timestamp == now)
    }

    @Test func testNegativeMantissaSignExtends() throws {
        // mantissa 0xFFFF9C = -100, exponent -1 => -10.0 C => 14.0 F
        let adapter: any ProbeAdapter = GenericGATTProbeAdapter()
        let reading = try #require(adapter.decode(Data([0x00, 0x9C, 0xFF, 0xFF, 0xFF]), now: Date()))
        #expect(abs(reading.internalF - 14.0) < 0.01)
    }
}

import Foundation

/// DUT-135 — turns raw BLE characteristic bytes into a reading. One adapter per probe family.
public protocol ProbeAdapter: Sendable {
    var serviceUUIDs: [String] { get }
    var temperatureCharacteristicUUID: String { get }
    func decode(_ data: Data, now: Date) -> ProbeReading?
}

/// Bluetooth SIG Health Thermometer, Temperature Measurement (0x2A1C).
public struct GenericGATTProbeAdapter: ProbeAdapter {
    public init() {}
    public let serviceUUIDs = ["1809"]
    public let temperatureCharacteristicUUID = "2A1C"
    public func decode(_ data: Data, now: Date = Date()) -> ProbeReading? {
        let bytes = [UInt8](data)
        guard bytes.count >= 5 else { return nil }
        // Bytes 1...3 are a 24-bit signed mantissa (little-endian); byte 4 is an 8-bit signed exponent.
        var mantissa = Int32(bytes[1]) | Int32(bytes[2]) << 8 | Int32(bytes[3]) << 16
        if mantissa & 0x800000 != 0 { mantissa |= ~0xFFFFFF }  // sign-extend
        let exponent = Int(Int8(bitPattern: bytes[4]))
        let value = Double(mantissa) * pow(10, Double(exponent))
        // Flags bit0: 1 means the value is Fahrenheit, otherwise Celsius.
        let fahrenheit = (bytes[0] & 0x01) != 0 ? value : value * 9 / 5 + 32
        return ProbeReading(internalF: fahrenheit, timestamp: now)
    }
}

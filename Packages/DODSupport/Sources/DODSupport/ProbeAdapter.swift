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
        return nil  // real decoding is added in the next sub-ticket
    }
}

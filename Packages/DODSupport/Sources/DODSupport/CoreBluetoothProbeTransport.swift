#if canImport(CoreBluetooth)
import CoreBluetooth
import Foundation

/// DUT-135 — live BLE transport. The central manager is created only in `startScan`.
public final class CoreBluetoothProbeTransport: NSObject, ProbeTransport, @unchecked Sendable {
    public var onReading: (@Sendable (Data) -> Void)?
    public var onState: (@Sendable (ProbeConnectionState) -> Void)?
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var serviceUUIDs: [CBUUID] = []
    private var characteristicUUID = CBUUID(string: "2A1C")

    public override init() { super.init() }

    public func startScan(serviceUUIDs: [String], characteristicUUID: String) {
        self.serviceUUIDs = serviceUUIDs.map { CBUUID(string: $0) }
        self.characteristicUUID = CBUUID(string: characteristicUUID)
        if let central {
            beginScanning(central)
        } else {
            central = CBCentralManager(delegate: self, queue: nil)  // scan starts in centralManagerDidUpdateState
        }
    }

    public func stop() {
        central?.stopScan()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
    }

    /// Maps the Bluetooth radio state to a connection state; nil means no change.
    nonisolated static func connectionState(for state: CBManagerState) -> ProbeConnectionState? {
        switch state {
        case .poweredOff, .unauthorized: return .unauthorized
        case .poweredOn: return .scanning
        default: return nil
        }
    }

    private func beginScanning(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: serviceUUIDs)
        onState?(.scanning)
    }
}

extension CoreBluetoothProbeTransport: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            beginScanning(central)
        } else if let mapped = Self.connectionState(for: central.state) {
            onState?(mapped)
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi _: NSNumber
    ) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        onState?(.connecting)
        central.connect(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(serviceUUIDs)
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        onState?(.lost)
    }
}

extension CoreBluetoothProbeTransport: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        for characteristic in service.characteristics ?? [] where characteristic.uuid == characteristicUUID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let data = characteristic.value { onReading?(data) }
    }
}
#endif

import Foundation

/// DUT-135 — seam over CoreBluetooth so the service is testable without hardware.
public protocol ProbeTransport: AnyObject, Sendable {
    var onReading: (@Sendable (Data) -> Void)? { get set }
    var onState: (@Sendable (ProbeConnectionState) -> Void)? { get set }
    /// Must be the first call that creates a CBCentralManager.
    func startScan(serviceUUIDs: [String], characteristicUUID: String)
    func stop()
}

@MainActor
public final class ProbeService {
    public private(set) var state: ProbeConnectionState = .idle
    public private(set) var lastReading: ProbeReading?
    public private(set) var hasConsented = false
    public var onReading: ((ProbeReading) -> Void)?
    private let transport: any ProbeTransport
    private let adapter: any ProbeAdapter

    public init(
        transport: any ProbeTransport,
        adapter: any ProbeAdapter = GenericGATTProbeAdapter()
    ) {
        self.transport = transport
        self.adapter = adapter
    }

    /// Call only after the first-run rationale screen is accepted.
    public func grantConsentAndScan() {
        hasConsented = true
        wire()
        transport.startScan(
            serviceUUIDs: adapter.serviceUUIDs,
            characteristicUUID: adapter.temperatureCharacteristicUUID
        )
        state = .scanning
    }

    public func stop() {
        transport.stop()
        state = .idle
    }

    private func wire() {
        let adapter = self.adapter
        transport.onReading = { [weak self] data in
            Task { @MainActor in
                guard let self, let reading = adapter.decode(data, now: Date()) else { return }
                self.lastReading = reading
                self.state = .connected
                self.onReading?(reading)
            }
        }
        transport.onState = { [weak self] newState in
            Task { @MainActor in self?.state = newState }
        }
    }
}

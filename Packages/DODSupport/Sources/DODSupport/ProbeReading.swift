import Foundation

/// DUT-135 — one sample from a BLE meat probe. Temperatures are °F.
public struct ProbeReading: Sendable, Equatable {
    public let internalF: Double
    public let ambientF: Double?
    public let batteryPercent: Int?
    public let timestamp: Date
    public init(internalF: Double, ambientF: Double? = nil, batteryPercent: Int? = nil, timestamp: Date = Date()) {
        self.internalF = internalF
        self.ambientF = ambientF
        self.batteryPercent = batteryPercent
        self.timestamp = timestamp
    }
}

public enum ProbeConnectionState: Sendable, Equatable {
    case idle, scanning, connecting, connected, outOfRange, lost, unauthorized
}

public enum ProbeAlert: Sendable, Equatable { case nearTarget, targetReached }

public struct ProbeAlertEvaluator: Sendable, Equatable {
    public let targetF: Double
    public let nearMarginF: Double
    public private(set) var firedNear = false
    public private(set) var firedTarget = false
    public init(targetF: Double, nearMarginF: Double = 10) {
        self.targetF = targetF
        self.nearMarginF = nearMarginF
    }
    /// Returns an alert at most once per kind. Reaching target also marks near as fired.
    public mutating func evaluate(_ reading: ProbeReading) -> ProbeAlert? {
        if !firedTarget, reading.internalF >= targetF {
            firedTarget = true
            firedNear = true
            return .targetReached
        }
        if !firedNear, reading.internalF >= targetF - nearMarginF {
            firedNear = true
            return .nearTarget
        }
        return nil
    }
}

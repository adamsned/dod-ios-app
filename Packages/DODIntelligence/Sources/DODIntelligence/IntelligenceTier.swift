import Foundation

/// Where an AI request is allowed to run (DUT-1005).
///
/// Architecture default: every AI feature runs on-device first. Private Cloud
/// Compute is a documented fallback only for a future feature that needs
/// heavier reasoning. It is never assumed per ticket.
public enum IntelligenceTier: String, Sendable, Equatable, CaseIterable {
    /// Apple's on-device FoundationModels language model. Free to run.
    case onDevice
    /// Private Cloud Compute. Free only under the App Store Small Business
    /// Program, and only when a feature explicitly opts in.
    case privateCloudCompute

    /// The tier every AI feature uses unless it documents otherwise.
    public static let `default`: IntelligenceTier = .onDevice

    /// `true` when the tier never leaves the device.
    public var isOnDevice: Bool { self == .onDevice }
}

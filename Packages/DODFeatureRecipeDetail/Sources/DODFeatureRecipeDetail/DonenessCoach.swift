import DODIntelligence
import Foundation
import Observation

/// DUT-1003 — state machine for the Cook Mode "Is It Done?" photo check.
/// Lives in its own type because `CookModeViewModel.swift` is at the SwiftLint
/// `file_length` cap; the view model holds one reference to this class.
@Observable
@MainActor
public final class DonenessCoach {
    public enum State: Equatable, Sendable {
        case idle
        case checking
        case result(DonenessCheckResult)
        case unavailable  // model returned nil
    }

    public private(set) var state: State = .idle
    private let intelligence: (any DODIntelligenceService)?

    public init(intelligence: (any DODIntelligenceService)?) { self.intelligence = intelligence }

    /// Show the camera affordance only when this is true; absent, not disabled.
    public var isAvailable: Bool {
        (intelligence?.isAvailable ?? false) && (intelligence?.supportsImageInput ?? false)
    }

    public func check(photo: Data, stepText: String) async {
        guard isAvailable, state != .checking else { return }
        state = .checking
        if let result = await intelligence?.checkDoneness(photo: photo, stepText: stepText) {
            state = .result(result)
        } else {
            state = .unavailable
        }
    }

    public func reset() { state = .idle }
}

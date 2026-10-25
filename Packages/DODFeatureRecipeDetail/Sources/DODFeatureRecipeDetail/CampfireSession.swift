import Foundation
import Observation

/// DUT-102 - Campfire Mode on/off state. Raises brightness to max while active
/// and restores the original value on exit.
@Observable
@MainActor
public final class CampfireSession {

    public private(set) var isActive = false
    public private(set) var variant: CampfireVariant = .day

    private let brightnessController: any ScreenBrightnessController
    private var priorBrightness: Double?

    public init(brightness: any ScreenBrightnessController = SystemScreenBrightnessController()) {
        self.brightnessController = brightness
    }

    public func toggleVariant() { variant = variant.toggled }
}

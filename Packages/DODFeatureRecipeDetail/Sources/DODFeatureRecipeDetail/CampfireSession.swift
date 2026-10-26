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

    /// Idempotent: a second call does not overwrite the saved brightness.
    public func enter() {
        guard !isActive else { return }
        isActive = true
        priorBrightness = brightnessController.brightness
        brightnessController.brightness = 1.0
    }

    /// Idempotent: safe to call from onDisappear even when never entered.
    public func exit() {
        guard isActive else { return }
        isActive = false
        if let priorBrightness { brightnessController.brightness = priorBrightness }
        priorBrightness = nil
    }

    public func toggle() {
        if isActive {
            exit()
        } else {
            enter()
        }
    }

    public func toggleVariant() { variant = variant.toggled }
}

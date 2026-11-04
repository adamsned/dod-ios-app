import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// DUT-102 - lets Campfire Mode drive screen brightness in production while
/// tests stub it with a plain class (same seam as ``IdleTimerController``).
@MainActor
public protocol ScreenBrightnessController: AnyObject {
    /// 0...1
    var brightness: Double { get set }
}

@MainActor
public final class SystemScreenBrightnessController: ScreenBrightnessController {

    public init() {}

    public var brightness: Double {
        get {
            #if canImport(UIKit) && !os(watchOS)
            Double(UIScreen.main.brightness)
            #else
            localValue
            #endif
        }
        set {
            let clamped = min(max(newValue, 0), 1)
            #if canImport(UIKit) && !os(watchOS)
            UIScreen.main.brightness = CGFloat(clamped)
            #else
            localValue = clamped
            #endif
        }
    }

    #if !(canImport(UIKit) && !os(watchOS))
    private var localValue: Double = 0.5
    #endif
}

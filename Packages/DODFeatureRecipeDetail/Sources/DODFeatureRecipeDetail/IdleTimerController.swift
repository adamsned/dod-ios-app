import Foundation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Idle timer abstraction
//
// Extracted from `CookModeViewModel.swift` (DUT-604) to keep that file under the
// SwiftLint 400-line `file_length` cap after the step-timer notifier seam
// landed. Behavior is unchanged — this is a pure move.

/// Lets the view model drive `UIApplication.isIdleTimerDisabled` in
/// production while letting tests stub the property with a plain class.
/// Marker-only protocol — the actual production conformance lives in
/// ``SystemIdleTimerController``.
@MainActor
public protocol IdleTimerController: AnyObject {
    var isDisabled: Bool { get set }
}

/// Production conformance — backed by `UIApplication.shared.isIdleTimerDisabled`.
/// On non-UIKit hosts (e.g. swift test on macOS), reads/writes a local
/// boolean so the type still satisfies the protocol.
@MainActor
public final class SystemIdleTimerController: IdleTimerController {

    public init() {}

    public var isDisabled: Bool {
        get {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled
            #else
            localValue
            #endif
        }
        set {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = newValue
            #else
            localValue = newValue
            #endif
        }
    }

    #if !canImport(UIKit)
    private var localValue: Bool = false
    #endif
}

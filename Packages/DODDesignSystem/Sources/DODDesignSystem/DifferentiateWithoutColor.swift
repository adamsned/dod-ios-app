import SwiftUI

#if canImport(UIKit)
/// DUT-121: when the system "Differentiate Without Color" setting is on, draw a
/// border so a color-coded capsule is distinguishable by outline, not only fill.
struct StatusOutlineModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    let level: StatusLevel
    /// Test seam: lets a test force the setting without a host environment.
    var forceDifferentiate: Bool?

    func body(content: Content) -> some View {
        let on = forceDifferentiate ?? differentiate
        content.overlay(
            Capsule().strokeBorder(level.color, lineWidth: on ? 2 : 0)
        )
    }

    static func borderWidth(differentiate: Bool) -> CGFloat { differentiate ? 2 : 0 }
}

extension View {
    /// Adds a status-colored outline when Differentiate Without Color is on.
    public func dodStatusOutline(_ level: StatusLevel) -> some View {
        modifier(StatusOutlineModifier(level: level, forceDifferentiate: nil))
    }
}
#endif

import SwiftUI

/// DUT-102 - the two Campfire Mode looks.
public enum CampfireVariant: String, CaseIterable, Sendable {
    /// Max-contrast light for bright sun: black on white.
    case day
    /// Red on black to preserve night vision at a dark campsite.
    case night

    public var background: Color {
        switch self {
        case .day: return Color(red: 1, green: 1, blue: 1)
        case .night: return Color(red: 0, green: 0, blue: 0)
        }
    }

    public var foreground: Color {
        switch self {
        case .day: return Color(red: 0, green: 0, blue: 0)
        case .night: return Color(red: 1, green: 0.15, blue: 0.1)
        }
    }

    /// Fill for the big Next/Prev buttons.
    public var buttonFill: Color {
        switch self {
        case .day: return Color(red: 0.88, green: 0.88, blue: 0.88)
        case .night: return Color(red: 0.25, green: 0, blue: 0)
        }
    }

    public var toggled: CampfireVariant { self == .day ? .night : .day }
    public var label: String { self == .day ? "Day" : "Night" }

    /// XXL step text (points). Used with `.minimumScaleFactor` in the view.
    public static let stepFontSize: CGFloat = 44
    /// Giant timer readout (points).
    public static let timerFontSize: CGFloat = 96
    /// Minimum Next/Prev hit-target height (points).
    public static let navButtonHeight: CGFloat = 120
}

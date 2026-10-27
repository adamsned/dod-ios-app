import SwiftUI

#if canImport(UIKit)
import UIKit

/// DUT-121: colorblind-safe semantic status tokens (Okabe-Ito hues).
/// Views must use these instead of raw `.red` / `.green`.
extension DODColor {
    /// Ready / success: bluish green. Light #009E73, dark #2FD0A3.
    public static let statusReady = statusColor(light: 0x009E73, dark: 0x2FD0A3)
    /// Caution / too cool: orange-yellow. Light #E69F00, dark #F5B83A.
    public static let statusCaution = statusColor(light: 0xB87400, dark: 0xF5B83A)
    /// Danger / too hot / failed: vermillion. Light #D55E00, dark #FF8A3D.
    public static let statusDanger = statusColor(light: 0xC24E00, dark: 0xFF8A3D)
    /// Neutral / info: blue. Light #0072B2, dark #56B4E9.
    public static let statusInfo = statusColor(light: 0x0072B2, dark: 0x56B4E9)

    private static func statusColor(light: UInt32, dark: UInt32) -> Color {
        Color(
            UIColor { trait in
                let hex = trait.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
            }
        )
    }
}

/// A status state plus the redundant non-color cues that go with it.
public enum StatusLevel: String, CaseIterable, Sendable {
    case ready, caution, danger, info

    public var color: Color {
        switch self {
        case .ready: DODColor.statusReady
        case .caution: DODColor.statusCaution
        case .danger: DODColor.statusDanger
        case .info: DODColor.statusInfo
        }
    }
    /// Distinct SF Symbol per state (shape differs, not just hue).
    public var systemImage: String {
        switch self {
        case .ready: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .danger: "flame.fill"
        case .info: "info.circle.fill"
        }
    }
    public var defaultLabel: String {
        switch self {
        case .ready: "Ready"
        case .caution: "Caution"
        case .danger: "Too hot"
        case .info: "Info"
        }
    }
}
#endif

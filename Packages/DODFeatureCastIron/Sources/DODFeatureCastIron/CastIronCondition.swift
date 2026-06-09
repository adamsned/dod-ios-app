import Foundation

/// The cast-iron condition states DUT-13 diagnoses from a photo, ordered
/// best -> worst so the UI can map severity to a color.
public enum CastIronCondition: String, CaseIterable, Codable, Sendable {
    case wellSeasoned
    case sticky
    case lightRust
    case heavyRust
    case cracked
    case neverSeasoned
    case notCastIron

    /// Short, friendly label for the diagnosis header.
    public var displayName: String {
        switch self {
        case .wellSeasoned: return "Well Seasoned"
        case .sticky: return "Sticky / Gummy"
        case .lightRust: return "Light Rust"
        case .heavyRust: return "Heavy Rust"
        case .cracked: return "Cracked"
        case .neverSeasoned: return "Never Seasoned"
        case .notCastIron: return "Not Cast Iron"
        }
    }

    /// Whether the pan can return to cooking service after care. A crack is
    /// terminal; `notCastIron` isn't ours to judge.
    public var isRecoverable: Bool {
        switch self {
        case .cracked, .notCastIron: return false
        default: return true
        }
    }
}

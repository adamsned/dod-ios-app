import Foundation

/// Why a dish was cooked (DUT-994). `.everyday` is the default for ordinary journal entries.
public enum CookOccasion: String, Sendable, Equatable, CaseIterable {
    case everyday
    case comfort  // cooking for someone having a hard day

    /// Lenient decode for persisted raw strings; unknown or nil falls back to `.everyday`.
    public init(rawValueOrDefault raw: String?) {
        self = raw.flatMap(CookOccasion.init(rawValue:)) ?? .everyday
    }
}

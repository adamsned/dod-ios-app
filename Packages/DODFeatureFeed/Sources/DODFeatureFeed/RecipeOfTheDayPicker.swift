import DODDomain
import Foundation

/// DUT-117 — deterministic Recipe of the Day selection. Pure: same pool + day key
/// + recent list always yields the same recipe. Not seasonal-weighted (future work).
enum RecipeOfTheDayPicker {

    /// Process-stable 64-bit FNV-1a hash.
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }
}

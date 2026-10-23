import DODDomain
import Foundation

/// DUT-117 — deterministic Recipe of the Day selection. Pure: same pool + day key
/// + recent list always yields the same recipe. Not seasonal-weighted (future work).
enum RecipeOfTheDayPicker {

    /// Picks from `pool` (sorted by id so input order never matters), skipping ids
    /// in `recent`. If every recipe is in `recent`, falls back to the whole pool.
    /// Returns nil for an empty pool.
    static func pick(from pool: [RecipeListItem], dayKey: String, excluding recent: [Int]) -> RecipeListItem? {
        guard !pool.isEmpty else { return nil }
        let sorted = pool.sorted { $0.id < $1.id }
        let fresh = sorted.filter { !recent.contains($0.id) }
        let candidates = fresh.isEmpty ? sorted : fresh
        return candidates[Int(fnv1a(dayKey) % UInt64(candidates.count))]
    }

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

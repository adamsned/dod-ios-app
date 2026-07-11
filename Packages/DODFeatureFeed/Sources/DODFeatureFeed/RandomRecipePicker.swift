import Foundation

/// DUT-939 — pure random-recipe-selection logic backing the Feed's
/// "Surprise Me" button (Android parity: Android already ships this, iOS
/// didn't). Mirrors `SearchViewModel.pickTrySlate`'s `inout any
/// RandomNumberGenerator` seam (T-639) so unit tests get a deterministic,
/// seeded pick while production draws from the kernel-seeded
/// `SystemRandomNumberGenerator` — same contract, same reason (a cold-launch
/// shuffle that isn't reproducible in prod but IS reproducible under test).
public enum RandomRecipePicker {

    /// Picks a random recipe id from `ids`, avoiding an immediate repeat of
    /// `lastShown` whenever another option exists.
    ///
    /// - `ids` empty → `nil`.
    /// - Exactly one id → that id, even when it equals `lastShown` (there's
    ///   nothing else to show).
    /// - More than one id, `lastShown` non-nil → `lastShown` is filtered out
    ///   of the candidate pool before picking, so the result never repeats
    ///   it. `lastShown` not being present in `ids` at all (e.g. the recipe
    ///   was removed from the feed since it was shown) is harmless — the
    ///   filter is a no-op and picking proceeds normally.
    /// - More than one id, `lastShown` nil → picks from the full list.
    public static func pick(
        from ids: [Int],
        excluding lastShown: Int?,
        using generator: inout any RandomNumberGenerator
    ) -> Int? {
        guard !ids.isEmpty else { return nil }
        guard ids.count > 1, let lastShown else {
            return ids.randomElement(using: &generator)
        }
        let candidates = ids.filter { $0 != lastShown }
        // Only reachable if every id in `ids` equals `lastShown` (e.g. a
        // degenerate list of duplicates) — fall back to the full list so a
        // non-empty `ids` never yields `nil`.
        guard !candidates.isEmpty else {
            return ids.randomElement(using: &generator)
        }
        return candidates.randomElement(using: &generator)
    }

    /// Convenience overload for production call sites — draws from the
    /// kernel-seeded `SystemRandomNumberGenerator` so callers don't need to
    /// thread a generator through by hand.
    public static func pick(from ids: [Int], excluding lastShown: Int?) -> Int? {
        var generator: any RandomNumberGenerator = SystemRandomNumberGenerator()
        return pick(from: ids, excluding: lastShown, using: &generator)
    }
}

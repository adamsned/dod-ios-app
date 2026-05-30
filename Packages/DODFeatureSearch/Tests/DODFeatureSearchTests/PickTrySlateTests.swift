import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

/// L1 unit tests for `SearchViewModel.pickTrySlate(...)` — the pure
/// helper that produces the rotating "Try" slate for the Search-tab
/// idle empty state (T-639 / CL-117 / US-29 amendment / AC-29.7).
///
/// The helper is `static` + pure (modulo the `inout RandomNumberGenerator`
/// seam) so every case here exercises a single function call against a
/// fixture pool and asserts the returned slate matches the AC-29.7
/// contract: pinned-Latest-Recipes-first + shuffle the remainder +
/// deterministic top-up if the pool is too small + empty-pool fallback
/// to the single pinned pill.
@Suite("pickTrySlate (T-639, CL-117, AC-29.7)") struct PickTrySlateTests {

    @Test func pool_of_30_visible_6_returns_6_with_latest_recipes_first() {
        let pool = Self.makePool(size: 30, includeLatestRecipes: true)
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rng
        )
        #expect(slate.count == 6)
        #expect(slate.first?.id == 1590)
        #expect(slate.first?.name == "Latest Recipes")
        // No Latest-Recipes pill in the rotation tail — the pin is the
        // single occurrence per the AC-29.7 contract.
        let tail = Array(slate.dropFirst())
        #expect(!tail.contains(where: { $0.id == 1590 }))
    }

    @Test func pool_missing_latest_recipes_still_returns_pinned_first() {
        let pool = Self.makePool(size: 20, includeLatestRecipes: false)
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 2)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rng
        )
        #expect(slate.count == 6)
        // Synthesized fallback per the AC-29.7 unconditional pin contract.
        #expect(slate.first?.id == 1590)
        #expect(slate.first?.name == "Latest Recipes")
        #expect(slate.first?.slug == "latest-recipes")
    }

    @Test func pool_smaller_than_visible_count_tops_up_deterministically() {
        // Pool has Latest Recipes + 2 rotatable items = 3 total. Visible
        // count 6 → slate is [pinned, A, B, A, B, A] (or similar repetition
        // of the shuffled tail). Critical contract: slate.count == 6 (no
        // short row), no nil/missing entries, pinned still first.
        var pool = [Self.makeCategory(id: 1, name: "Alpha")]
        pool.append(Self.makeCategory(id: 2, name: "Beta"))
        pool.append(Self.makeCategory(id: 1590, name: "Latest Recipes"))
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 3)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rng
        )
        #expect(slate.count == 6)
        #expect(slate.first?.id == 1590)
        // Tail uses only the two rotatable categories.
        let tailIDs = Set(slate.dropFirst().map(\.id))
        #expect(tailIDs == Set([1, 2]))
    }

    @Test func empty_pool_returns_just_latest_recipes() {
        let pool: [DODDomain.Category] = []
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 4)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rng
        )
        #expect(slate.count == 1)
        #expect(slate.first?.id == 1590)
        #expect(slate.first?.name == "Latest Recipes")
    }

    @Test func pool_with_only_latest_recipes_returns_just_latest_recipes() {
        // Edge case: pool has Latest Recipes but nothing rotatable.
        // Per AC-29.7 the slate degrades to the single pinned pill.
        let pool = [Self.makeCategory(id: 1590, name: "Latest Recipes")]
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 5)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rng
        )
        #expect(slate.count == 1)
        #expect(slate.first?.id == 1590)
    }

    @Test func same_seed_and_same_pool_returns_same_slate() {
        // Determinism contract under a seeded RNG — important so the
        // production cold-launch shuffle (which uses `SystemRandomNumberGenerator`)
        // is observably driven by RNG state, not by something else.
        let pool = Self.makePool(size: 30, includeLatestRecipes: true)
        var rng1: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        var rng2: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let slate1 = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rng1
        )
        let slate2 = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rng2
        )
        #expect(slate1.map(\.id) == slate2.map(\.id))
    }

    @Test func different_seeds_typically_yield_different_slates() {
        // Sanity check that the shuffle is actually consuming the RNG.
        // With a 29-item rotation pool and 5 tail slots, two different
        // seeds produce different first-tail picks with overwhelming
        // probability; this catches the bug where the helper ignores
        // the RNG entirely.
        let pool = Self.makePool(size: 30, includeLatestRecipes: true)
        var rngA: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        var rngB: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 999_999)
        let slateA = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rngA
        )
        let slateB = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rngB
        )
        #expect(slateA.map(\.id) != slateB.map(\.id))
    }

    @Test func visible_count_1_returns_just_latest_recipes() {
        let pool = Self.makePool(size: 10, includeLatestRecipes: true)
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 6)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 1,
            using: &rng
        )
        #expect(slate.count == 1)
        #expect(slate.first?.id == 1590)
    }

    // MARK: - Fixtures

    static func makeCategory(id: Int, name: String) -> DODDomain.Category {
        DODDomain.Category(id: id, name: name, slug: name.lowercased(), count: 1)
    }

    static func makePool(size: Int, includeLatestRecipes: Bool) -> [DODDomain.Category] {
        var pool: [DODDomain.Category] = []
        for idx in 1...size {
            if idx == 1 && includeLatestRecipes {
                pool.append(makeCategory(id: 1590, name: "Latest Recipes"))
            } else {
                pool.append(makeCategory(id: idx + 100, name: "Cat\(idx)"))
            }
        }
        return pool
    }
}

/// Deterministic RNG for tests. Linear-congruential generator — Numerical
/// Recipes constants. Pinned to ensure the test slate matches across
/// machines and toolchain versions (`SystemRandomNumberGenerator` is
/// kernel-seeded so not reproducible).
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

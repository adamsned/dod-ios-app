import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

/// L1 unit tests for `SearchViewModel.pickTrySlate(...)` — the pure helper
/// that produces the "Try Searching" slate for the Search-tab idle empty
/// state (T-639 / CL-117 → v2 Search overhaul (3/3)).
///
/// Wave 3 swapped the source from WP categories to the curated 100-term
/// string pool (``SearchTryChips/pool``) and the element type from
/// `DODDomain.Category` to ``SearchTryChip``. The helper stays `static` +
/// pure (modulo the `inout RandomNumberGenerator` seam): every case runs a
/// single call against a fixture pool and asserts the returned slate matches
/// the contract — pinned-Latest-Recipes-first + shuffle the remainder +
/// deterministic top-up if the pool is too small + empty-pool fallback to the
/// single pinned pill.
@Suite("pickTrySlate (v2 Search overhaul 3/3)") struct PickTrySlateTests {

    @Test func pool_of_30_visible_10_returns_10_with_latest_recipes_first() {
        let pool = Self.makePool(size: 30)
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 10,
            using: &rng
        )
        #expect(slate.count == 10)
        #expect(slate.first?.isLatestRecipes == true)
        #expect(slate.first?.display == "Latest Recipes")
        // No Latest-Recipes pill in the rotation tail — the pin is the single
        // occurrence; every tail chip carries a real raw query.
        let tail = Array(slate.dropFirst())
        #expect(!tail.contains(where: { $0.isLatestRecipes }))
        #expect(tail.allSatisfy { !$0.query.isEmpty })
    }

    @Test func real_pool_slate_draws_tail_from_the_curated_pool() {
        // End-to-end against the production 100-term pool: every tail chip's
        // raw query must be a member of `SearchTryChips.pool`.
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 7)
        let slate = SearchViewModel.pickTrySlate(
            from: SearchTryChips.pool,
            visibleCount: SearchViewModel.trySlateVisibleCount,
            using: &rng
        )
        #expect(slate.count == SearchViewModel.trySlateVisibleCount)
        #expect(slate.first?.isLatestRecipes == true)
        let poolSet = Set(SearchTryChips.pool)
        let tail = Array(slate.dropFirst())
        #expect(tail.allSatisfy { poolSet.contains($0.query) })
        // With 99 free slots and 9 tail chips, no repeats.
        #expect(Set(tail.map(\.query)).count == tail.count)
    }

    @Test func pool_smaller_than_visible_count_tops_up_deterministically() {
        // Pool has 2 rotatable terms. Visible count 6 → slate is
        // [pinned, A, B, A, B, A] (repetition of the shuffled tail).
        // Contract: slate.count == 6 (no short row), pinned still first,
        // tail uses only the two pool terms.
        let pool = ["alpha", "beta"]
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 3)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rng
        )
        #expect(slate.count == 6)
        #expect(slate.first?.isLatestRecipes == true)
        let tailQueries = Set(slate.dropFirst().map(\.query))
        #expect(tailQueries == Set(["alpha", "beta"]))
    }

    @Test func empty_pool_returns_just_latest_recipes() {
        let pool: [String] = []
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 4)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 10,
            using: &rng
        )
        #expect(slate.count == 1)
        #expect(slate.first?.isLatestRecipes == true)
        #expect(slate.first?.display == "Latest Recipes")
    }

    @Test func same_seed_and_same_pool_returns_same_slate() {
        // Determinism contract under a seeded RNG — proves the cold-launch
        // shuffle is observably driven by RNG state.
        let pool = Self.makePool(size: 30)
        var rng1: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        var rng2: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        let slate1 = SearchViewModel.pickTrySlate(from: pool, visibleCount: 10, using: &rng1)
        let slate2 = SearchViewModel.pickTrySlate(from: pool, visibleCount: 10, using: &rng2)
        #expect(slate1.map(\.id) == slate2.map(\.id))
    }

    @Test func different_seeds_typically_yield_different_slates() {
        // Sanity check that the shuffle actually consumes the RNG.
        let pool = Self.makePool(size: 30)
        var rngA: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        var rngB: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 999_999)
        let slateA = SearchViewModel.pickTrySlate(from: pool, visibleCount: 10, using: &rngA)
        let slateB = SearchViewModel.pickTrySlate(from: pool, visibleCount: 10, using: &rngB)
        #expect(slateA.map(\.id) != slateB.map(\.id))
    }

    @Test func visible_count_1_returns_just_latest_recipes() {
        let pool = Self.makePool(size: 10)
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 6)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 1,
            using: &rng
        )
        #expect(slate.count == 1)
        #expect(slate.first?.isLatestRecipes == true)
    }

    // MARK: - Fixtures

    /// Build a pool of `size` raw terms ("term1", "term2", ...). Latest
    /// Recipes is synthesized by the helper (not one of the pool terms), so
    /// fixtures no longer inject it.
    static func makePool(size: Int) -> [String] {
        (1...size).map { "term\($0)" }
    }
}

/// Deterministic RNG for tests. Linear-congruential generator — Numerical
/// Recipes constants. Pinned to ensure the test slate matches across machines
/// and toolchain versions (`SystemRandomNumberGenerator` is kernel-seeded so
/// not reproducible).
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

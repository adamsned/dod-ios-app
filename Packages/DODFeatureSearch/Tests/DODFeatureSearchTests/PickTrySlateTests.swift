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
/// `DODDomain.Category` to ``SearchTryChip``. The v2 feed-search redesign
/// (2026-09-25) then dropped the special pinned "Latest Recipes" pill, so the
/// slate is now a pure shuffle over the pool + deterministic top-up when the
/// pool is smaller than the requested count + an empty slate for an empty pool.
@Suite("pickTrySlate (v2 Search overhaul 3/3)") struct PickTrySlateTests {

    @Test func pool_of_30_visible_10_returns_10_pool_terms() {
        let pool = Self.makePool(size: 30)
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 10,
            using: &rng
        )
        #expect(slate.count == 10)
        // No pinned Latest Recipes pill any more — every chip is a real pool
        // term with a non-empty raw query.
        #expect(!slate.contains(where: { $0.isLatestRecipes }))
        #expect(slate.allSatisfy { !$0.query.isEmpty })
    }

    @Test func real_pool_slate_draws_from_the_curated_pool() {
        // End-to-end against the production 100-term pool: every chip's raw
        // query must be a member of `SearchTryChips.pool`.
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 7)
        let slate = SearchViewModel.pickTrySlate(
            from: SearchTryChips.pool,
            visibleCount: SearchViewModel.trySlateVisibleCount,
            using: &rng
        )
        #expect(slate.count == SearchViewModel.trySlateVisibleCount)
        #expect(!slate.contains(where: { $0.isLatestRecipes }))
        let poolSet = Set(SearchTryChips.pool)
        #expect(slate.allSatisfy { poolSet.contains($0.query) })
        // With 100 terms and 10 slots, no repeats.
        #expect(Set(slate.map(\.query)).count == slate.count)
    }

    @Test func pool_smaller_than_visible_count_tops_up_deterministically() {
        // Pool has 2 terms. Visible count 6 → the shuffled tail repeats to fill
        // (e.g. [A, B, A, B, A, B]). Contract: slate.count == 6 (no short row),
        // uses only the two pool terms, no pinned pill.
        let pool = ["alpha", "beta"]
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 3)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 6,
            using: &rng
        )
        #expect(slate.count == 6)
        #expect(!slate.contains(where: { $0.isLatestRecipes }))
        #expect(Set(slate.map(\.query)) == Set(["alpha", "beta"]))
    }

    @Test func empty_pool_returns_empty_slate() {
        let pool: [String] = []
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 4)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 10,
            using: &rng
        )
        #expect(slate.isEmpty)
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

    @Test func visible_count_1_returns_one_pool_chip() {
        let pool = Self.makePool(size: 10)
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 6)
        let slate = SearchViewModel.pickTrySlate(
            from: pool,
            visibleCount: 1,
            using: &rng
        )
        #expect(slate.count == 1)
        #expect(slate.first?.isLatestRecipes == false)
        #expect(slate.first.map { !$0.query.isEmpty } == true)
    }

    // MARK: - Fixtures

    /// Build a pool of `size` raw terms ("term1", "term2", ...).
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

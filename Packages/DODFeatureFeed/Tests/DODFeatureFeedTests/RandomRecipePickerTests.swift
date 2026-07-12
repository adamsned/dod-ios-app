import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 unit tests for `RandomRecipePicker.pick(...)` — the pure helper behind
/// the Feed's "Surprise Me" button (DUT-939, Android parity). Mirrors
/// `PickTrySlateTests`' seeded-RNG determinism pattern (T-639) so the
/// "avoid an immediate repeat" contract is exercised without ever touching
/// `SystemRandomNumberGenerator`.
@Suite("RandomRecipePicker (DUT-939)") struct RandomRecipePickerTests {

    @Test func empty_ids_list_returns_nil() {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let result = RandomRecipePicker.pick(from: [], excluding: nil, using: &rng)
        #expect(result == nil)
    }

    @Test func single_id_returns_that_id_even_when_it_equals_last_shown() {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 2)
        let result = RandomRecipePicker.pick(from: [7], excluding: 7, using: &rng)
        #expect(result == 7)
    }

    @Test func multiple_ids_with_non_nil_last_shown_never_repeats_it() {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 3)
        let ids = [1, 2, 3, 4]
        let lastShown = 2
        for _ in 0..<100 {
            let result = RandomRecipePicker.pick(from: ids, excluding: lastShown, using: &rng)
            #expect(result != lastShown)
        }
    }

    @Test func every_result_is_a_member_of_the_input_ids() throws {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 4)
        let idsA = [10, 20, 30]
        let resultA = try #require(RandomRecipePicker.pick(from: idsA, excluding: nil, using: &rng))
        #expect(idsA.contains(resultA))

        let idsB = [5, 15, 25, 35]
        let resultB = try #require(RandomRecipePicker.pick(from: idsB, excluding: 15, using: &rng))
        #expect(idsB.contains(resultB))
    }

    @Test func excluding_an_id_not_in_the_list_is_harmless() throws {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 5)
        let ids = [7, 14, 21]
        let result = try #require(RandomRecipePicker.pick(from: ids, excluding: 99, using: &rng))
        #expect(ids.contains(result))
    }

    @Test func nil_last_shown_with_multiple_ids_still_returns_a_member() throws {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 6)
        let ids = [8, 16, 24, 32]
        let result = try #require(RandomRecipePicker.pick(from: ids, excluding: nil, using: &rng))
        #expect(ids.contains(result))
    }

    @Test func production_convenience_overload_returns_a_member_of_the_input() throws {
        let ids = [100, 200, 300]
        let result = try #require(RandomRecipePicker.pick(from: ids, excluding: nil))
        #expect(ids.contains(result))
    }

    @Test func degenerate_case_all_items_equal_to_excluded_falls_back_to_full_list() throws {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 7)
        let ids = [7, 7, 7, 7]
        // All items equal the excluded value; should fall back to full list (line 37-39)
        let result = try #require(RandomRecipePicker.pick(from: ids, excluding: 7, using: &rng))
        #expect(result == 7)
        #expect(ids.contains(result))
    }

    @Test func degenerate_case_with_different_duplicate_value() throws {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 8)
        let ids = [99, 99, 99]
        let result = try #require(RandomRecipePicker.pick(from: ids, excluding: 99, using: &rng))
        #expect(result == 99)
    }
}

/// Deterministic RNG for tests — Numerical Recipes LCG constants, pinned so
/// results are reproducible across machines/toolchains
/// (`SystemRandomNumberGenerator` is kernel-seeded and is not). Mirrors the
/// private `SeededRandomNumberGenerator` in `PickTrySlateTests.swift`
/// (DODFeatureSearchTests) — kept as a separate copy here since it's a tiny,
/// test-file-scoped fixture, not shared production code.
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

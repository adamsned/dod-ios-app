import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

/// Genuine-gap tests for CookTimeFormatter, CookTimeChipLabel, and RecentSearches.
/// Spec trace: US-12, AC-12.4, CL-122, REG-31.
@Suite("Pure Helper Edge Cases: Formatter & Recents")
struct PureHelperGapFormatterTests {

    // MARK: - CookTimeFormatter edge cases

    /// Very large seconds value (approaching Int.max / 3600).
    @Test func cookTimeFormatterVeryLargeSeconds() {
        let largeSeconds = (Int.max / 3600) * 3600
        let label = CookTimeFormatter.label(seconds: largeSeconds)
        #expect(!label.isEmpty, "Large seconds should produce a valid label")
        #expect(label.contains("hr"), "Large value should render as hours")
    }

    /// Cook time formatter at 1-hour boundary (3600 seconds).
    @Test func cookTimeFormatterAt1HourBoundary() {
        #expect(CookTimeFormatter.label(seconds: 3600) == "1 hr")
    }

    /// Cook time formatter at 1-hour plus 1 second (should still round to 1 hr).
    @Test func cookTimeFormatterAt1HourPlus1Second() {
        #expect(CookTimeFormatter.label(seconds: 3601) == "1 hr")
    }

    /// Cook time formatter at 1-hour minus 1 second (should be 59 min).
    @Test func cookTimeFormatterAt1HourMinus1Second() {
        #expect(CookTimeFormatter.label(seconds: 3599) == "59 min")
    }

    /// Multiple hours with no leftover minutes.
    @Test func cookTimeFormatterMultipleHoursExact() {
        #expect(CookTimeFormatter.label(seconds: 3 * 3600) == "3 hr")
        #expect(CookTimeFormatter.label(seconds: 5 * 3600) == "5 hr")
    }

    /// Multiple hours with leftover minutes.
    @Test func cookTimeFormatterMultipleHoursWithLeftover() {
        #expect(CookTimeFormatter.label(seconds: 2 * 3600 + 15 * 60) == "2 hr 15 min")
        #expect(CookTimeFormatter.label(seconds: 3 * 3600 + 45 * 60) == "3 hr 45 min")
    }

    // MARK: - CookTimeChipLabel edge cases

    /// Chip label when both bounds are the same at a non-trivial value.
    @Test func cookTimeChipLabelMinEqualsMaxNonTrivial() {
        #expect(cookTimeChipLabel(min: 45 * 60, max: 45 * 60) == "45 min")
        #expect(cookTimeChipLabel(min: 90 * 60, max: 90 * 60) == "1 hr 30 min")
    }

    /// Chip label when min equals max at a boundary (exactly 1 hour).
    @Test func cookTimeChipLabelMinEqualsMaxAt1Hour() {
        #expect(cookTimeChipLabel(min: 3600, max: 3600) == "1 hr")
    }

    /// Chip label for a range crossing the 1-hour boundary.
    @Test func cookTimeChipLabelRangeCrosses1Hour() {
        #expect(cookTimeChipLabel(min: 45 * 60, max: 90 * 60) == "45 min–1 hr 30 min")
        #expect(cookTimeChipLabel(min: 30 * 60, max: 3600) == "30 min–1 hr")
    }

    /// Chip label with very tight range (1 minute apart).
    @Test func cookTimeChipLabelTightRange() {
        #expect(
            cookTimeChipLabel(min: 29 * 60, max: 30 * 60) == "29 min–30 min"
        )
    }

    // MARK: - RecentSearches pure logic edge cases

    /// Record and then remove at exactly maxEntries boundary: after hitting
    /// the limit, adding one more and removing one should keep the store valid.
    @Test func recordAndRemoveAtMaxEntriesBoundary() {
        let recents = scratch()
        // Fill to maxEntries
        for index in 0..<RecentSearches.maxEntries {
            recents.record("q\(index)")
        }
        #expect(recents.recent().count == RecentSearches.maxEntries)

        // Record one more (evicts the oldest)
        recents.record("new")
        #expect(recents.recent().count == RecentSearches.maxEntries)
        #expect(recents.recent().first == "new")

        // Remove from the middle
        recents.remove("q5")
        #expect(recents.recent().count == RecentSearches.maxEntries - 1)
    }

    /// Record with leading/trailing whitespace gets trimmed.
    @Test func recordWithLeadingTrailingWhitespace() {
        let recents = scratch()
        recents.record("  pizza  ")
        #expect(recents.recent() == ["pizza"])
    }

    /// Record with tab characters gets trimmed.
    @Test func recordWithTabCharacters() {
        let recents = scratch()
        recents.record("\t\tpizza\t\t")
        #expect(recents.recent() == ["pizza"])
    }

    /// Record with newline characters gets trimmed.
    @Test func recordWithNewlineCharacters() {
        let recents = scratch()
        recents.record("\npizza\n")
        #expect(recents.recent() == ["pizza"])
    }

    /// Record with mixed whitespace (space, tab, newline).
    @Test func recordWithMixedWhitespace() {
        let recents = scratch()
        recents.record(" \t\npizza\n\t ")
        #expect(recents.recent() == ["pizza"])
    }

    /// Dedupe case-insensitively: recording "Test" then "test" keeps only one.
    @Test func dedupePreservesCasingOfLastRecord() {
        let recents = scratch()
        recents.record("Pizza")
        recents.record("pizza")
        #expect(recents.recent().count == 1)
        #expect(recents.recent().first == "pizza", "Latest casing is preserved")
    }

    /// Remove with leading/trailing whitespace matches correctly.
    @Test func removeWithLeadingTrailingWhitespace() {
        let recents = scratch()
        recents.record("pizza")
        recents.record("pasta")
        recents.remove("  pizza  ")
        #expect(recents.recent() == ["pasta"])
    }

    /// Remove non-existent entry (case-insensitive) is a no-op.
    @Test func removeNonExistentEntryIsNoOp() {
        let recents = scratch()
        recents.record("pizza")
        recents.remove("burger")
        #expect(recents.recent() == ["pizza"])
    }

    /// Clear after recording leaves an empty store.
    @Test func clearAfterRecordingLeavesEmpty() {
        let recents = scratch()
        recents.record("pizza")
        recents.record("pasta")
        recents.clear()
        #expect(recents.recent().isEmpty)
    }

    /// Successive records with same query (case variations) only keeps latest.
    @Test func successiveIdenticalQueriesDifferentCasing() {
        let recents = scratch()
        recents.record("PIZZA")
        recents.record("Pizza")
        recents.record("pizza")
        #expect(recents.recent().count == 1)
        #expect(recents.recent().first == "pizza")
    }

    /// Record and remove in alternating pattern doesn't corrupt state.
    @Test func alternatingRecordAndRemove() {
        let recents = scratch()
        recents.record("a")
        recents.record("b")
        recents.remove("a")
        recents.record("c")
        recents.record("a")
        #expect(
            recents.recent() == ["a", "c", "b"],
            "Alternating record/remove maintains consistency"
        )
    }

    // MARK: - Helper

    private func scratch() -> RecentSearches {
        let suiteName = "dod.pureHelperGapFormatterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}

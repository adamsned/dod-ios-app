import Foundation
import Testing

@testable import DODCookActivity

// MARK: - formattedCookActivityCountdown

/// L1 unit tests for the internal ``formattedCookActivityCountdown(_:)`` helper.
///
/// The function clamps negative input to 0, then formats as `mm:ss` (< 1 hour)
/// or `H:MM:SS` (≥ 1 hour) to match the self-updating `Text(timerInterval:)`
/// format (DUT-404).  All expected values are derived directly from the
/// implementation arithmetic — no guessing.
@Suite("formattedCookActivityCountdown")
struct FormattedCookActivityCountdownTests {

    @Test("formats 0 seconds as 00:00")
    func formatsZeroSeconds() {
        #expect(formattedCookActivityCountdown(0) == "00:00")
    }

    @Test("formats 59 seconds as 00:59")
    func formats59Seconds() {
        #expect(formattedCookActivityCountdown(59) == "00:59")
    }

    @Test("formats 60 seconds as 01:00")
    func formats60Seconds() {
        #expect(formattedCookActivityCountdown(60) == "01:00")
    }

    @Test("formats 3599 seconds as 59:59 — boundary just below one hour")
    func formats3599Seconds() {
        #expect(formattedCookActivityCountdown(3599) == "59:59")
    }

    @Test("formats 3600 seconds as 1:00:00 — switches to H:MM:SS at exactly one hour")
    func formats3600Seconds() {
        #expect(formattedCookActivityCountdown(3600) == "1:00:00")
    }

    @Test("formats 3661 seconds as 1:01:01")
    func formats3661Seconds() {
        #expect(formattedCookActivityCountdown(3661) == "1:01:01")
    }

    @Test("clamps negative input to 0 and returns 00:00")
    func clampsNegativeToZero() {
        #expect(formattedCookActivityCountdown(-5) == "00:00")
    }

    @Test("formats 36000 seconds as 10:00:00")
    func formats10Hours() {
        #expect(formattedCookActivityCountdown(36000) == "10:00:00")
    }

    /// Regression: Int.max must not overflow or trap anywhere in the
    /// division, modulo, or String(format:) pipeline.
    @Test("Int.max does not trap and returns a non-empty string")
    func intMaxDoesNotTrap() {
        let result = formattedCookActivityCountdown(Int.max)
        #expect(!result.isEmpty)
    }
}

// MARK: - CookActivityAttributes Codable

/// L1 tests for ``CookActivityAttributes`` JSON encoding / decoding.
@Suite("CookActivityAttributes Codable round-trip")
struct CookActivityAttributesCodableTests {

    @Test("attributes round-trip through JSONEncoder then JSONDecoder")
    func roundTripsAttributes() throws {
        let original = CookActivityAttributes(
            recipeTitle: "Cast Iron Cornbread",
            recipeID: 42,
            totalSeconds: 1800
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CookActivityAttributes.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - ContentState Codable

/// L1 tests for ``CookActivityAttributes/ContentState`` JSON encoding / decoding,
/// including the custom `init(from decoder:)` backward-compat paths.
@Suite("CookActivityAttributes.ContentState Codable")
struct ContentStateCodableTests {

    // Fixed reference date to avoid flaky Date() equality comparisons.
    // 725_760_000 seconds after 2001-01-01 == 2024-01-01 00:00:00 UTC.
    private let fixedDate = Date(timeIntervalSinceReferenceDate: 725_760_000)

    @Test("ContentState round-trips through JSON with all fields set including endDate")
    func roundTripsAllFields() throws {
        let original = CookActivityAttributes.ContentState(
            remainingSeconds: 90,
            stepText: "Brown the meat",
            isPaused: false,
            endDate: fixedDate,
            isCompleted: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            CookActivityAttributes.ContentState.self,
            from: data
        )
        #expect(decoded == original)
    }

    @Test("ContentState round-trips with isCompleted true and no endDate")
    func roundTripsIsCompletedTrue() throws {
        let original = CookActivityAttributes.ContentState(
            remainingSeconds: 0,
            stepText: "Done",
            isPaused: true,
            endDate: nil,
            isCompleted: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            CookActivityAttributes.ContentState.self,
            from: data
        )
        #expect(decoded == original)
    }
}

// MARK: - ContentState custom-decoder backward compat

/// Verifies that payloads encoded before optional fields were added decode
/// correctly rather than throwing — the `decodeIfPresent(…) ?? default`
/// pattern documented in the source (DUT-490 / DUT-491).
@Suite("CookActivityAttributes.ContentState custom decoder backward compat")
struct ContentStateBackwardCompatTests {

    /// A JSON payload that predates the `isCompleted` key must decode with
    /// `isCompleted == false` (the documented default).
    @Test("JSON omitting isCompleted decodes with isCompleted == false")
    func omittedIsCompletedDefaultsFalse() throws {
        // Pre-DUT-490 payload: no isCompleted key → must default to false.
        let json = "{\"remainingSeconds\":120,\"stepText\":\"Sear\",\"isPaused\":false}"
        let decoded = try JSONDecoder().decode(
            CookActivityAttributes.ContentState.self,
            from: Data(json.utf8)
        )
        #expect(decoded.isCompleted == false)
    }

    /// A JSON payload that omits `endDate` must decode with `endDate == nil`.
    @Test("JSON omitting endDate decodes with endDate == nil")
    func omittedEndDateDecodesNil() throws {
        let json =
            "{\"remainingSeconds\":120,\"stepText\":\"Sear\",\"isPaused\":false,\"isCompleted\":false}"
        let decoded = try JSONDecoder().decode(
            CookActivityAttributes.ContentState.self,
            from: Data(json.utf8)
        )
        #expect(decoded.endDate == nil)
    }
}

// MARK: - ContentState Equatable + Hashable

/// L1 tests for the synthesized ``Equatable`` and ``Hashable`` conformances on
/// ``CookActivityAttributes/ContentState``.
@Suite("CookActivityAttributes.ContentState Equatable and Hashable")
struct ContentStateEquatableHashableTests {

    // Shared fixed date so both instances in each test have the same endDate.
    private let fixedDate = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test("states with all identical field values are equal")
    func identicalStatesAreEqual() {
        let lhs = CookActivityAttributes.ContentState(
            remainingSeconds: 300,
            stepText: "Simmer",
            isPaused: false,
            endDate: fixedDate,
            isCompleted: false
        )
        let rhs = CookActivityAttributes.ContentState(
            remainingSeconds: 300,
            stepText: "Simmer",
            isPaused: false,
            endDate: fixedDate,
            isCompleted: false
        )
        #expect(lhs == rhs)
    }

    @Test("states that differ only in remainingSeconds are not equal")
    func differingRemainingSecondsNotEqual() {
        let lhs = CookActivityAttributes.ContentState(
            remainingSeconds: 300,
            stepText: "Simmer",
            isPaused: false
        )
        let rhs = CookActivityAttributes.ContentState(
            remainingSeconds: 600,
            stepText: "Simmer",
            isPaused: false
        )
        #expect(lhs != rhs)
    }

    /// Hashable contract: `lhs == rhs` implies `lhs.hashValue == rhs.hashValue`.
    @Test("equal states have the same hash value")
    func equalStatesHaveSameHash() {
        let lhs = CookActivityAttributes.ContentState(
            remainingSeconds: 300,
            stepText: "Simmer",
            isPaused: false,
            endDate: fixedDate,
            isCompleted: false
        )
        let rhs = CookActivityAttributes.ContentState(
            remainingSeconds: 300,
            stepText: "Simmer",
            isPaused: false,
            endDate: fixedDate,
            isCompleted: false
        )
        #expect(lhs.hashValue == rhs.hashValue)
    }
}

// MARK: - CookActivityAttributes Equatable

/// L1 tests for the synthesized ``Equatable`` conformance on
/// ``CookActivityAttributes`` (the immutable outer struct).
@Suite("CookActivityAttributes Equatable")
struct CookActivityAttributesEquatableTests {

    @Test("attributes with all identical fields are equal")
    func identicalAttributesAreEqual() {
        let lhs = CookActivityAttributes(recipeTitle: "Chili", recipeID: 7, totalSeconds: 3600)
        let rhs = CookActivityAttributes(recipeTitle: "Chili", recipeID: 7, totalSeconds: 3600)
        #expect(lhs == rhs)
    }

    @Test("attributes that differ only in recipeID are not equal")
    func differingRecipeIDNotEqual() {
        let lhs = CookActivityAttributes(recipeTitle: "Chili", recipeID: 7, totalSeconds: 3600)
        let rhs = CookActivityAttributes(recipeTitle: "Chili", recipeID: 8, totalSeconds: 3600)
        #expect(lhs != rhs)
    }
}

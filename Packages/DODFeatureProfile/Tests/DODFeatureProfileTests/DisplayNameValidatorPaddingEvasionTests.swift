import Testing

@testable import DODFeatureProfile

/// DUT-708 regression — repeated-letter padding must not let blocklisted slurs
/// slip past the moderation check. `collapseRuns` must collapse runs to ONE
/// letter (not two), so "fuuuuck" → "fuck" → blocked. Formerly it collapsed
/// to two, so "fuuuuck" → "fuuck" ≠ "fuck" → passed as .ok (the bug).
@Suite("DisplayNameValidator padding-evasion (DUT-708)")
struct DisplayNameValidatorPaddingEvasionTests {

    // MARK: - Padded slurs (3+ repeated letters)

    @Test("padded slurs with 3+ repeated letters are blocked")
    func paddedSlursAreBlocked() {
        #expect(DisplayNameValidator.validate("fuuuuck") == .inappropriate)
        #expect(DisplayNameValidator.validate("fuuuuuck") == .inappropriate)
        #expect(DisplayNameValidator.validate("shiiit") == .inappropriate)
        #expect(DisplayNameValidator.validate("biiiitch") == .inappropriate)
        #expect(DisplayNameValidator.validate("asssshole") == .inappropriate)
    }

    // MARK: - Doubled-interior-letter evasion (2 repeated letters)

    @Test("doubled-interior-letter evasions are also blocked")
    func doubledInteriorLetterEvasionsAreBlocked() {
        // These collapsed to two letters under the old (buggy) collapse-to-two
        // scheme — e.g. "fuuck" ≠ "fuck" — and slipped past. They must not now.
        #expect(DisplayNameValidator.validate("fuuck") == .inappropriate)
        #expect(DisplayNameValidator.validate("shhit") == .inappropriate)
    }

    // MARK: - Clean names still pass

    @Test("clean names still return .ok after the fix")
    func cleanNamesAreOk() {
        #expect(DisplayNameValidator.validate("SpencerAdams") == .ok)
        #expect(DisplayNameValidator.validate("Ned") == .ok)
        #expect(DisplayNameValidator.validate("GrillMaster") == .ok)
    }

    // MARK: - normalize collapses runs to exactly one letter

    @Test("normalize collapses repeated letters to a single letter")
    func normalizeCollapsesRuns() {
        // Confirm the run-collapse is to ONE, not two.
        #expect(DisplayNameValidator.normalize("fuuuuck") == "fuck")
        #expect(DisplayNameValidator.normalize("shiiit") == "shit")
        #expect(DisplayNameValidator.normalize("aaa") == "a")
        #expect(DisplayNameValidator.normalize("hello") == "helo")
    }
}

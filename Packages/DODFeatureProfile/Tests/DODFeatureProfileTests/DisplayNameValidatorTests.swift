import Testing

@testable import DODFeatureProfile

@Suite("DisplayNameValidator (DUT-415)") struct DisplayNameValidatorTests {

    // MARK: - Empty

    @Test func blankIsEmpty() {
        #expect(DisplayNameValidator.validate("") == .empty)
        #expect(DisplayNameValidator.validate("   ") == .empty)
        #expect(DisplayNameValidator.validate("\n\t") == .empty)
    }

    @Test func punctuationOrEmojiOnlyIsEmpty() {
        // Nothing left to show after stripping non-letters.
        #expect(DisplayNameValidator.validate("...") == .empty)
        #expect(DisplayNameValidator.validate("🙂🔥") == .empty)
    }

    // MARK: - Acceptable names

    @Test func ordinaryNamesAreOk() {
        for name in ["Spencer Adams", "Ned", "Mary-Jane", "José", "Renée", "O'Brien", "李雷 Lei"] {
            #expect(DisplayNameValidator.validate(name) == .ok, "\(name) should be ok")
        }
    }

    @Test func innocentNamesWithRiskySubstringsAreOk() {
        // The Scunthorpe problem: short blocked words must NOT match as substrings.
        for name in ["Cassandra", "Dick", "Hancock", "Assassin's Fan", "Cumberland", "Tittle"] {
            #expect(DisplayNameValidator.validate(name) == .ok, "\(name) should be ok")
        }
    }

    // MARK: - Vulgar

    @Test func plainProfanityIsBlocked() {
        for name in ["Fuck", "shithead", "Big Bitch", "asshole supreme"] {
            #expect(DisplayNameValidator.validate(name) == .inappropriate, "\(name) should be blocked")
        }
    }

    @Test func evasionTricksAreBlocked() {
        // leetspeak, spacing, punctuation, diacritics, repeats all normalize back.
        for name in ["sh1t", "@sshole", "F U C K", "f.u.c.k", "Fück", "b i t c h"] {
            #expect(DisplayNameValidator.validate(name) == .inappropriate, "\(name) should be blocked")
        }
    }

    @Test func shortSlursBlockedAsWholeWords() {
        #expect(DisplayNameValidator.validate("ass") == .inappropriate)
        #expect(DisplayNameValidator.validate("Big Ass Joe") == .inappropriate)
    }

    // MARK: - Barred figures

    @Test func notoriousFiguresAreBlocked() {
        for name in ["Adolf Hitler", "Hitler", "Stalin", "Osama bin Laden", "Jeffrey Dahmer", "I am Hitler"] {
            #expect(DisplayNameValidator.validate(name) == .inappropriate, "\(name) should be blocked")
        }
    }
}

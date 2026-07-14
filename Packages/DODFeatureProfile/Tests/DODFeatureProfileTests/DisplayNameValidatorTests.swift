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

    @Test func spacedOutShortSlursAreBlocked() {
        // Letter-spacing (or punctuation between every letter) used to split a
        // short blocked word into single-character tokens ("a", "s", "s"),
        // none of which matched the whole-word blocklist — bypassing it
        // entirely even though normalization is supposed to defeat exactly
        // this kind of evasion (same trick as "h e l l o" for the substring
        // list, just against the whole-word list instead).
        #expect(DisplayNameValidator.validate("a s s") == .inappropriate)
        #expect(DisplayNameValidator.validate("f.a.g") == .inappropriate)
        // A genuine multi-word name must still be unaffected.
        #expect(DisplayNameValidator.validate("Big Ass Joe") == .inappropriate)
        #expect(DisplayNameValidator.validate("Cassandra") == .ok)
    }

    // MARK: - Barred figures

    @Test func notoriousFiguresAreBlocked() {
        for name in ["Adolf Hitler", "Hitler", "Stalin", "Osama bin Laden", "Jeffrey Dahmer", "I am Hitler"] {
            #expect(DisplayNameValidator.validate(name) == .inappropriate, "\(name) should be blocked")
        }
    }

    // MARK: - Substring-collision false positives

    @Test func nigerAndDemonymsAreNotFalselyBlocked() {
        // Regression: the anti-evasion `collapseRuns` step normalizes the blocked
        // slur "nigger" down to "niger" (its doubled "g" collapses to one), which
        // then collided with the legitimate country name / demonyms as a
        // substring match. None of these should trip the moderation check.
        for name in ["Niger", "Nigeria", "Nigerian", "Nigerien", "niger", "NIGERIA"] {
            #expect(DisplayNameValidator.validate(name) == .ok, "\(name) should be ok")
        }
    }

    @Test func actualSlurStillBlockedAlongsideAllowlistedWord() {
        // The allowlist only exempts an EXACT normalized full-name match, so a
        // genuinely inappropriate name doesn't get a free pass just because it
        // also contains "Nigeria" as a substring or prefix.
        #expect(DisplayNameValidator.validate("Nigeria Fuck") == .inappropriate)
        #expect(DisplayNameValidator.validate("nigger") == .inappropriate)
    }

    @Test func slurEvasionsStillBlockedDespiteAllowlist() {
        // The allowlist is keyed on the PRE-collapse (doubled-letter-preserving)
        // form, not the fully-collapsed one, specifically so it can't be
        // (ab)used to smuggle the slur back in via padding/spacing evasions
        // that still collapse down to "niger".
        for name in ["niiggerr", "n-i-g-g-e-r", "N1GGER", "nigga"] {
            #expect(DisplayNameValidator.validate(name) == .inappropriate, "\(name) should be blocked")
        }
    }
}

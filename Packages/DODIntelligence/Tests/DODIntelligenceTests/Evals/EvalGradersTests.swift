import Testing

@testable import DODIntelligence

@Suite("EvalGraders")
struct EvalGradersTests {

    @Test func nonEmptyRejectsNilAndWhitespace() {
        #expect(EvalGraders.nonEmpty(nil).count == 1)
        #expect(EvalGraders.nonEmpty("  \n\t").count == 1)
        #expect(EvalGraders.nonEmpty("hello").isEmpty)
    }

    @Test func forbidsIsCaseInsensitive() {
        #expect(EvalGraders.forbids(["Definitely Safe"], in: "it is definitely safe").count == 1)
    }

    @Test func requiresAnyPassesWhenOneMatches() {
        #expect(EvalGraders.requiresAny(["thermometer", "check"], in: "Use a Thermometer").isEmpty)
    }

    @Test func requiresAnyFailsWhenNoneMatch() {
        #expect(EvalGraders.requiresAny(["thermometer", "check"], in: "just eat it").count == 1)
    }

    @Test func integersExtractsInOrder() {
        #expect(EvalGraders.integers(in: "use 24 coals, 12 on top") == [24, 12])
    }

    @Test func numbersGroundedFlagsOnlyUnknown() {
        #expect(
            EvalGraders.numbersGrounded(in: "24 coals, 99 minutes", allowed: [24])
                == ["ungrounded number 99"]
        )
    }
}

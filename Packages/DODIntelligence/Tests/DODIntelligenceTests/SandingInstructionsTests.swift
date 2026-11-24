import Testing

@testable import DODIntelligence

@Suite("SandingInstructions")
struct SandingInstructionsTests {
    @Test func chatInstructionsForbidSanding() {
        #if os(iOS)
        if #available(iOS 26, *) {
            let texts = [
                LiveDODIntelligenceService.helperInstructions, LiveDODIntelligenceService.recipeChatInstructions,
            ]
            for text in texts {
                #expect(text.contains("Never, ever mention, suggest or describe sanding"))
                #expect(text.contains("steel wool"))
            }
        }
        #endif
    }

    @Test func fakeSandingAnswerBecomesFallback() {
        let fake = "Rough spot? Sand it down with 120-grit sandpaper."
        #expect(SandingGuard.sanitize(fake) == SandingGuard.fallback)
    }
}

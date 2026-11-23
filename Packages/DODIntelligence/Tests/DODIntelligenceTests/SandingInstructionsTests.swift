import Testing

@testable import DODIntelligence

@Suite("SandingInstructions")
struct SandingInstructionsTests {
    @Test func fakeSandingAnswerBecomesFallback() {
        let fake = "Rough spot? Sand it down with 120-grit sandpaper."
        #expect(SandingGuard.sanitize(fake) == SandingGuard.fallback)
    }
}

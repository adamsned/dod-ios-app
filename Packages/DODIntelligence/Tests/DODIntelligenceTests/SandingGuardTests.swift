import Testing

@testable import DODIntelligence

@Suite("SandingGuard")
struct SandingGuardTests {
    @Test(arguments: [
        "Sand it down first",
        "use 80-grit sandpaper",
        "an orbital sander",
        "a flap disc works",
        "use an angle grinder",
        "It was SANDED smooth",
    ])
    func detectsSanding(_ text: String) {
        #expect(SandingGuard.containsSandingMention(text))
    }

    @Test(arguments: [
        "make a sandwich",
        "a thousand thanks",
        "line the sandbox",
        "scrub with steel wool",
    ])
    func ignoresLookalikes(_ text: String) {
        #expect(!SandingGuard.containsSandingMention(text))
    }
}

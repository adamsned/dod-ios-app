import Testing

@testable import DODSupport

@Suite("CookOccasion (DUT-994)")
struct CookOccasionTests {
    @Test func nilFallsBackToEveryday() {
        #expect(CookOccasion(rawValueOrDefault: nil) == .everyday)
    }

    @Test func unknownFallsBackToEveryday() {
        #expect(CookOccasion(rawValueOrDefault: "zzz") == .everyday)
    }

    @Test func comfortRoundTrips() {
        #expect(CookOccasion(rawValueOrDefault: CookOccasion.comfort.rawValue) == .comfort)
    }
}

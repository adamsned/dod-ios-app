import Testing

@testable import DODSupport

@Suite("GuidedCookout tier (DUT-964)")
struct GuidedCookoutTierTests {

    @Test("onlyTheCampfireIsOutdoor")
    func onlyTheCampfireIsOutdoor() {
        for rung in GuidedCookout.path {
            #expect(rung.isCampfire == (rung.tier == .outdoor))
        }
    }

    @Test("pathEndsOutdoorAfterHomeRungs")
    func pathEndsOutdoorAfterHomeRungs() {
        #expect(GuidedCookout.path.last?.tier == .outdoor)
        #expect(GuidedCookout.path.dropLast().allSatisfy { $0.tier == .home })
    }

    @Test("everyRungHasANote")
    func everyRungHasANote() {
        for rung in GuidedCookout.path {
            #expect(!rung.forgivingNote.isEmpty)
            #expect(!rung.forgivingNote.contains("—"))
        }
    }
}

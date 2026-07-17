import Testing

@testable import DODFeatureFeed

@Suite("FirstCookoutView Stage Icon Tests")
@MainActor
struct FirstCookoutViewStageIconTests {

    let view = FirstCookoutView()

    @Test("Gather stage returns checklist icon")
    func gatherStageReturnsChecklistIcon() {
        let result = view.stageIcon(.gather)
        #expect(result == "checklist")
    }

    @Test("Fire stage returns flame.fill icon")
    func fireStageReturnsFlameFillIcon() {
        let result = view.stageIcon(.fire)
        #expect(result == "flame.fill")
    }

    @Test("Cook stage returns frying.pan.fill icon")
    func cookStageReturnsFryingPanFillIcon() {
        let result = view.stageIcon(.cook)
        #expect(result == "frying.pan.fill")
    }

    @Test("Celebrate stage returns party.popper.fill icon")
    func celebrateStageReturnsPartyPopperFillIcon() {
        let result = view.stageIcon(.celebrate)
        #expect(result == "party.popper.fill")
    }
}

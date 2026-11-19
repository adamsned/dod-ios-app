import DODDesignSystem
import Testing

@testable import DODFeatureRecipeDetail

@Suite("RecipeDetail availability mapping (DUT-1670)")
struct RecipeDetailAvailabilityTests {
    @Test("downloaded recipe works offline")
    func downloadedWorksOffline() {
        #expect(RecipeDetailView.availability(isDownloaded: true) == .worksOffline)
    }

    @Test("not-downloaded recipe needs network")
    func notDownloadedNeedsNetwork() {
        #expect(RecipeDetailView.availability(isDownloaded: false) == .needsNetwork)
    }
}

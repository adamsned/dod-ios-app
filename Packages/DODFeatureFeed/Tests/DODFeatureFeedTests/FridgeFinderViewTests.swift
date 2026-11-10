import DODIntelligence
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite("FridgeFinderView (DUT-1979)")
struct FridgeFinderViewTests {
    @Test func viewConstructs() {
        let viewModel = FridgeFinderViewModel(
            intelligence: FakeIntelligenceService(),
            loadRecipes: { [] }
        )
        _ = FridgeFinderView(viewModel: viewModel, onSelect: { _ in })
    }
}

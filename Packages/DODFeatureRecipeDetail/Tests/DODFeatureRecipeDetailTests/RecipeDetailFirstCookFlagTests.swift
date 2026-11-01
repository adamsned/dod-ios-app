import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-986 — `isFirstCookEver` defaults to false until `refreshProfile()` resolves it.
@MainActor
@Suite("RecipeDetailViewModel.isFirstCookEver (DUT-986)")
struct RecipeDetailFirstCookFlagTests {
    @Test func defaultsToFalseOnFreshViewModel() {
        let dependencies = FakeRecipeDetailDependencies()
        let vm = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 2080),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/2080/")
                ?? URL(filePath: "/"),
            dependencies: dependencies
        )
        #expect(vm.isFirstCookEver == false)
    }
}

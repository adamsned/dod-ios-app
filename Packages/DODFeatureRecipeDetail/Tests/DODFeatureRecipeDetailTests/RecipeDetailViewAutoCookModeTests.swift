import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1240 — a recipe opened via the Cooking Tools hub's Cook Mode "Find a
/// Recipe" (`autoStartCookMode: true`) must tell its host
/// (`onAutoCookModeStarted`) the instant Cook Mode actually auto-presents —
/// not at construction, not on tap. The host (`TabStack`) uses that signal,
/// not the tap or a tab switch, to disarm the "we came here to cook" flag, so
/// a SECOND recipe tapped on the same Feed visit (without re-choosing "Find a
/// Recipe") no longer auto-starts Cook Mode.
///
/// These pin ``RecipeDetailView/handleLoadStateChange(_:)`` directly by
/// constructing a bare (non-hosted) `RecipeDetailView` and calling it. Only
/// the callback-firing outcome (a plain closure capture) is asserted — a
/// bare `@State` property's `nonmutating set` is a documented no-op without
/// SwiftUI's runtime installing a storage `Location`, so reading
/// `isCookModePresented` / `pendingAutoCookMode` back off an unhosted `view`
/// after a mutating call would not reflect the mutation and isn't a
/// meaningful assertion here.
@MainActor
@Suite("RecipeDetailView auto Cook Mode (DUT-1240)") struct RecipeDetailViewAutoCookModeTests {

    private static func makeReadyViewModel(id: Int, withDetail: Bool = true) async -> RecipeDetailViewModel {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: id, withDetail: withDetail)
        let viewModel = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: id),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
            dependencies: dependencies
        )
        await viewModel.onAppear()
        return viewModel
    }

    @Test func firesOnAutoCookModeStartedWhenArmedAndReadyWithInstructions() async {
        var fired = false
        let viewModel = await Self.makeReadyViewModel(id: 1)
        let view = RecipeDetailView(
            viewModel: viewModel,
            onSelectRelated: { _ in },
            autoStartCookMode: true,
            onAutoCookModeStarted: { fired = true }
        )

        view.handleLoadStateChange(.ready)

        #expect(fired, "the host must be told the instant Cook Mode auto-presents")
    }

    @Test func doesNotFireWhenNotArmed() async {
        var fired = false
        let viewModel = await Self.makeReadyViewModel(id: 2)
        let view = RecipeDetailView(
            viewModel: viewModel,
            onSelectRelated: { _ in },
            autoStartCookMode: false,
            onAutoCookModeStarted: { fired = true }
        )

        view.handleLoadStateChange(.ready)

        #expect(!fired, "a plain (non-Cook-Mode) open must never disarm the host's flag")
    }

    @Test func doesNotFireWhenArmedButRecipeHasNoInstructionsYet() async {
        var fired = false
        // `withDetail: false` yields empty instructions — mirrors the recipe
        // still loading its detail payload.
        let viewModel = await Self.makeReadyViewModel(id: 3, withDetail: false)
        let view = RecipeDetailView(
            viewModel: viewModel,
            onSelectRelated: { _ in },
            autoStartCookMode: true,
            onAutoCookModeStarted: { fired = true }
        )

        view.handleLoadStateChange(.ready)

        #expect(
            !fired,
            "Cook Mode can't start without instructions — the arm must stay intact upstream so a retry (once the recipe finishes loading) can still work"
        )
    }

    @Test func doesNotFireForNonReadyLoadStateEvenWhenArmed() async {
        var fired = false
        let viewModel = await Self.makeReadyViewModel(id: 4)
        let view = RecipeDetailView(
            viewModel: viewModel,
            onSelectRelated: { _ in },
            autoStartCookMode: true,
            onAutoCookModeStarted: { fired = true }
        )

        view.handleLoadStateChange(.loadingDetail)

        #expect(!fired, "only a genuinely .ready recipe can auto-present Cook Mode")
    }
}

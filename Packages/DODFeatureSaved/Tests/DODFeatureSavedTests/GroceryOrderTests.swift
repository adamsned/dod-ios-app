import DODNetworking
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the "Order ingredients" grocery-ordering wiring on the
/// Shopping List (DUT-532): the still-need subset feeding the CTA (must match
/// the Share subset), the end-to-end map → link flow through a fake
/// ``GroceryOrderLinking`` for each provider, and the config / provider gate
/// that drives whether the CTA renders nothing, a single button, or a menu.
@MainActor
@Suite("Order ingredients (DUT-532)")
struct GroceryOrderTests {

    /// Records the last `createLink` call + returns a canned URL, so a VM-level
    /// test drives the CTA flow without the network.
    private final class FakeLinking: GroceryOrderLinking, @unchecked Sendable {
        var lastProvider: GroceryProvider?
        var lastTitle: String?
        var lastLineItems: [GroceryLineItem] = []
        let url: URL
        init(url: URL) { self.url = url }
        func createLink(
            provider: GroceryProvider,
            title: String,
            lineItems: [GroceryLineItem]
        ) async throws -> URL {
            lastProvider = provider
            lastTitle = title
            lastLineItems = lineItems
            return url
        }
    }

    // MARK: - Still-need subset (matches the Share subset)

    @Test func stillNeedLinesDropsCheckedAndAlreadyHave() {
        let keep = item("2 limes", "Tacos", .produce)
        let checkedOff = item("1 lb chicken thighs", "Tacos", .meat)
        let alreadyHave = item("1 tsp salt", "Tacos", .spices)
        let viewModel = ShoppingListViewModel(items: [keep, checkedOff, alreadyHave], store: nil)
        viewModel.toggleChecked(checkedOff)
        viewModel.markAlreadyHave(alreadyHave)

        // Same shape ShoppingListFormatter.shareText excludes (CL-85): checked +
        // already-have rows drop; only "2 limes" remains.
        #expect(ShoppingListFormatter.stillNeedLines(viewModel) == ["2 limes"])
    }

    // MARK: - Map → link flow (per provider)

    @Test func createsLinkFromStillNeedLinesWithMappedItems() async throws {
        let linkURL = try #require(URL(string: "https://instacart.com/store/x"))
        let fake = FakeLinking(url: linkURL)
        let lines = ShoppingListFormatter.stillNeedLines(
            ShoppingListViewModel(
                items: [
                    item("1 lb chicken thighs", "Tacos", .meat),
                    item("2 limes", "Tacos", .produce),
                ],
                store: nil
            )
        )
        let lineItems = GroceryLineItemMapper.lineItems(from: lines)
        let url = try await fake.createLink(
            provider: .walmartPlus,
            title: GroceryLineItemMapper.defaultTitle,
            lineItems: lineItems
        )

        #expect(url.absoluteString == "https://instacart.com/store/x")
        #expect(fake.lastProvider == .walmartPlus)
        #expect(fake.lastTitle == "Dutch Oven Daddy Shopping List")
        #expect(fake.lastLineItems.count == 2)
        #expect(fake.lastLineItems[0].name == "chicken thighs")
        #expect(fake.lastLineItems[0].unit == "pound")
        #expect(fake.lastLineItems[1].name == "limes")
        #expect(fake.lastLineItems[1].quantity == 2)
    }

    // MARK: - CTA gate (drives whether / how the CTA renders)

    @Test func ctaHiddenWhenUnconfigured() {
        // Production default is the dormant placeholder — no providers enabled,
        // so the CTA never renders (production ships dormant).
        #expect(GroceryOrderConfig.production.enabledProviders.isEmpty)
    }

    @Test func ctaHiddenWhenConfiguredButNoProviders() {
        let config = GroceryOrderConfig(endpointURLString: "https://worker.example.workers.dev")
        #expect(config.enabledProviders.isEmpty)
    }

    @Test func ctaShowsSingleButtonForOneProvider() {
        // One enabled provider → the toolbar takes the single-button path.
        let config = GroceryOrderConfig(
            endpointURLString: "https://worker.example.workers.dev",
            providers: [.instacart]
        )
        #expect(config.enabledProviders.count == 1)
        #expect(config.enabledProviders == [.instacart])
    }

    @Test func ctaShowsMenuForMultipleProviders() {
        // Two enabled providers → the toolbar takes the menu path.
        let config = GroceryOrderConfig(
            endpointURLString: "https://worker.example.workers.dev",
            providers: [.instacart, .walmartPlus]
        )
        #expect(config.enabledProviders.count == 2)
        #expect(config.enabledProviders == [.instacart, .walmartPlus])
    }

    // MARK: - Fixtures

    private func item(
        _ text: String,
        _ recipe: String,
        _ aisle: IngredientAisleClassifier.Aisle
    ) -> ShoppingListViewModel.Item {
        ShoppingListViewModel.Item(ingredientText: text, recipeTitle: recipe, aisle: aisle)
    }
}

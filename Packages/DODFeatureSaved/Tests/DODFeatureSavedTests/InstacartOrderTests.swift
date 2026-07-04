import DODNetworking
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the "Order on Instacart" wiring on the Shopping List
/// (DUT-532): the still-need subset feeding the CTA (must match the Share
/// subset), the end-to-end map → link flow through a fake
/// ``InstacartShoppingListLinking``, and the config gate.
@MainActor
@Suite("Order on Instacart (DUT-532)")
struct InstacartOrderTests {

    /// Records the last `createLink` call + returns a canned URL, so a VM-level
    /// test drives the CTA flow without the network.
    private final class FakeLinking: InstacartShoppingListLinking, @unchecked Sendable {
        var lastTitle: String?
        var lastLineItems: [InstacartLineItem] = []
        let url: URL
        init(url: URL) { self.url = url }
        func createLink(title: String, lineItems: [InstacartLineItem]) async throws -> URL {
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

    // MARK: - Map → link flow

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
        let lineItems = InstacartLineItemMapper.lineItems(from: lines)
        let url = try await fake.createLink(
            title: InstacartLineItemMapper.defaultTitle,
            lineItems: lineItems
        )

        #expect(url.absoluteString == "https://instacart.com/store/x")
        #expect(fake.lastTitle == "Dutch Oven Daddy Shopping List")
        #expect(fake.lastLineItems.count == 2)
        #expect(fake.lastLineItems[0].name == "chicken thighs")
        #expect(fake.lastLineItems[0].unit == "pound")
        #expect(fake.lastLineItems[1].name == "limes")
        #expect(fake.lastLineItems[1].quantity == 2)
    }

    // MARK: - Config gate (drives whether the CTA is shown)

    @Test func ctaHiddenWhenConfigNotConfigured() {
        // Production default is the dormant placeholder — the CTA's gate is off,
        // so the button never renders (production ships dormant).
        #expect(InstacartConfig.production.isConfigured == false)
    }

    @Test func ctaGateOnForRealEndpoint() {
        #expect(
            InstacartConfig(endpointURLString: "https://worker.example.workers.dev").isConfigured
        )
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

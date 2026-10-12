import DODAnalytics
import DODDomain
import Foundation

// DUT-1388 — wire the Siri / Shortcuts intents to the app's live services.

extension AppDependencies {

    /// Called from `DODApp.init`, right after the composition root is built and
    /// BEFORE any scene exists. A background Siri intent ("Save this recipe",
    /// "Add the ingredients to my shopping list") can launch the app without a
    /// scene, so `bootstrap()` (a scene `.task`) never runs; registering here
    /// means the intents always find the store + actions.
    ///
    /// Also adds the ``IntentDonationTransport`` (must precede
    /// `Telemetry.start`, which `bootstrap()` calls).
    func registerAppIntents() {
        AppIntentEnvironment.register(store: store)
        let client = restClient
        let appender = shoppingListAppender()
        AppIntentEnvironment.register(
            actions: AppIntentActions(
                searchRecipes: { query in try await client.search(query: query) },
                fetchPost: { id in try await client.post(id: id) },
                save: { [self] item in
                    await TabStack.saveFromCard(item: item, store: store, publisher: savedWidgetPublisher())
                },
                addToShoppingList: { recipe in await appender.addToShoppingList(recipe) }
            )
        )
        Telemetry.shared.addTransport(IntentDonationTransport())
    }
}

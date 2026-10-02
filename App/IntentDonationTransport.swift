import AppIntents
import DODAnalytics
import Foundation

/// DUT-1388 — donates Siri suggestions from what the cook actually does.
///
/// Opening a recipe donates ``OpenRecipeIntent`` and starting Cook Mode donates
/// ``StartCookModeIntent`` for it, so Siri Suggestions, Spotlight, and the Lock
/// Screen can offer "Cook Brown Butter Gnocchi" around the times the cook
/// usually does. Rides the existing telemetry fan-out (the recipe screen already
/// sends `recipeView` / `cookModeStarted`), so no feature package changes.
///
/// Donations stay on device (they are not analytics), so this transport ignores
/// the telemetry opt-out on purpose.
struct IntentDonationTransport: TelemetryTransport {

    func configure(appID: String) {}

    func send(_ event: AnalyticsEvent) {
        guard let donation = Self.donation(for: event) else { return }
        Task {
            guard let payload = await RecipeEntityQuery.payload(id: donation.recipeID) else { return }
            let entity = RecipeEntity(payload: payload)
            switch donation.kind {
            case .open: _ = try? await IntentDonationManager.shared.donate(intent: OpenRecipeIntent(target: entity))
            case .cook: _ = try? await IntentDonationManager.shared.donate(intent: StartCookModeIntent(recipe: entity))
            }
        }
    }

    enum Kind: Equatable { case open, cook }

    /// Pure event → donation mapping (unit-tested).
    static func donation(for event: AnalyticsEvent) -> (kind: Kind, recipeID: Int)? {
        switch event {
        case .recipeView(let id): (.open, id)
        case .cookModeStarted(let id): (.cook, id)
        default: nil
        }
    }
}

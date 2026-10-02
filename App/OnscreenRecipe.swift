import AppIntents
import Foundation
import Observation
import SwiftUI

/// DUT-1388 — the recipe currently on screen, so Siri can act on "this".
///
/// Two consumers:
/// 1. The recipe intents (Start Cook Mode / Save / Add to Shopping List) fall
///    back to it when no recipe was named ("Save this recipe in Dutch Oven
///    Daddy"), which works on every OS version.
/// 2. ``OnscreenRecipeActivity`` publishes it as the `NSUserActivity`
///    `appEntityIdentifier` (iOS 18.2+), which is how Siri's onscreen awareness
///    learns which ``RecipeEntity`` the user is looking at.
///
/// Driven by `TabStack.recipeDetailView`'s appear / disappear. A disappear only
/// clears the value when it is still THIS recipe, so pushing a related recipe
/// (new one appears first) or popping back (the revealed one re-appears) never
/// leaves a stale or empty value behind.
@MainActor
@Observable
final class OnscreenRecipe {

    static let shared = OnscreenRecipe()

    private(set) var payload: RecipeEntityPayload?

    init() {}

    func show(_ payload: RecipeEntityPayload) {
        self.payload = payload
    }

    func hide(id: Int) {
        if payload?.id == id { payload = nil }
    }

    /// The recipe an intent should act on: the one Siri named, else the one on
    /// screen, else nil (the intent then asks "Which recipe?").
    static func resolve(_ named: RecipeEntity?) -> RecipeEntity? {
        named ?? shared.payload.map(RecipeEntity.init(payload:))
    }
}

/// Publishes ``OnscreenRecipe`` as a "viewing a recipe" user activity while a
/// recipe screen is up. Applied once on `RootView`.
struct OnscreenRecipeActivity: ViewModifier {

    static let activityType = "com.dutchovendaddy.DODApp.viewRecipe"

    @State private var onscreen = OnscreenRecipe.shared

    func body(content: Content) -> some View {
        content.userActivity(Self.activityType, isActive: onscreen.payload != nil) { activity in
            guard let payload = onscreen.payload else { return }
            activity.title = payload.title
            if #available(iOS 18.2, *) {
                activity.appEntityIdentifier = EntityIdentifier(for: RecipeEntity(payload: payload))
            }
        }
    }
}

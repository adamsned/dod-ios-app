import DODDomain
import SwiftUI

/// DUT-1014 — marks an ingredient row as an addressable on-screen entity and
/// registers it in ``OnscreenIngredients`` while visible.
@MainActor
struct IngredientAnnotation: ViewModifier {
    let entry: OnscreenIngredients.Entry
    var registry: OnscreenIngredients = .shared

    func body(content: Content) -> some View {
        annotated(content)
            .onAppear { registry.appear(entry) }
            .onDisappear { registry.disappear(id: entry.id) }
    }

    @ViewBuilder
    private func annotated(_ content: Content) -> some View {
        if #available(iOS 27, *) {
            // TODO(2026-10-29, nadams): replace with the confirmed iOS 27 View Annotations
            // call, keyed by entry.id.uuidString. Fallback if the SDK has no such
            // symbol: the .userActivity + appEntityIdentifier pattern in
            // App/OnscreenRecipe.swift (needs an AppEntity in the App target).
            content
        } else {
            content
        }
    }
}

extension View {
    func ingredientAnnotation(_ entry: OnscreenIngredients.Entry) -> some View {
        modifier(IngredientAnnotation(entry: entry))
    }
}

import SwiftUI

// v2 on-device AI — the Shopping List's substitution sheet presenter, pulled out
// of `ShoppingListView.body` so that body's modifier chain stays simple enough
// for the Swift type-checker (a second inline `.sheet` with three closures tips
// it into a "unable to type-check in reasonable time" failure) and so the capped
// `ShoppingListView.swift` file stays under the SwiftLint 400-line limit.
extension View {

    /// Present the ingredient-substitution sheet: pick reason → Suggest (runs the
    /// on-device model) → Apply (replaces the row). Bound to the view model's
    /// substitution state via `isPresented`.
    func shoppingSubstitutionSheet(
        isPresented: Binding<Bool>,
        viewModel: ShoppingListViewModel
    ) -> some View {
        sheet(isPresented: isPresented) {
            SubstitutionSheet(
                state: viewModel.substitution,
                onSuggest: { reason in
                    Task { await viewModel.generateSubstitution(reason: reason) }
                },
                onApply: { viewModel.applySubstitution() },
                onCancel: { viewModel.dismissSubstitution() }
            )
        }
    }
}

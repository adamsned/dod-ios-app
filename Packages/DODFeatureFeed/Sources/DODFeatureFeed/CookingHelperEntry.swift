import DODIntelligence
import SwiftUI

/// T-934 (US-54 / AC-54.4) — the self-contained Cooking Tools "Ask Dutch Oven
/// Daddy" hub entry: the availability gate + the tool card + the helper sheet,
/// packaged so the hub can drop it into its tool list without owning any new
/// state (the hub view is already at its SwiftLint `file_length` cap).
///
/// **Availability gating hides the whole entry.** The card renders ONLY when the
/// injected ``DODIntelligenceService`` reports `isAvailable`; on an unsupported
/// device the body is empty, so there is no dead row — mirroring how the
/// Shopping List omits its "Substitute" affordance.
///
/// **Injection mirrors the substitution seam.** The App threads
/// `dependencies.intelligenceService()` in at the composition point (the hub's
/// tool list), exactly as `GroceryTabRoot` threads it into
/// `ShoppingListViewModel`. The card's visual is supplied by the caller as a
/// closure so it reuses the hub's own `toolCard` builder verbatim.
public struct CookingHelperEntry<Card: View>: View {

    @State private var viewModel: CookingHelperViewModel
    @State private var isPresented = false

    /// Builds the tappable tool card, given the tap action. The hub passes its
    /// own `toolCard(...)` so the helper row matches every other hub card.
    private let card: (_ action: @escaping () -> Void) -> Card

    /// - Parameters:
    ///   - intelligence: The on-device AI seam from `AppDependencies`. When it
    ///     is unavailable (or `nil`), the entry renders nothing.
    ///   - card: Builds the tool card from the tap action (reuses the hub's
    ///     shared card styling).
    public init(
        intelligence: (any DODIntelligenceService)?,
        @ViewBuilder card: @escaping (_ action: @escaping () -> Void) -> Card
    ) {
        _viewModel = State(initialValue: CookingHelperViewModel(intelligence: intelligence))
        self.card = card
    }

    public var body: some View {
        if viewModel.isAvailable {
            card { isPresented = true }
                .sheet(isPresented: $isPresented, onDismiss: viewModel.reset) {
                    CookingHelperSheet(viewModel: viewModel) { isPresented = false }
                }
        }
    }
}

import DODDesignSystem
import SwiftUI

/// Cook Mode's floating top controls (redesigned) — the back control and the
/// ingredients button, overlaid on the immersive ``CookModeHero``'s blur strip
/// rather than sitting in a separate title bar.
///
/// The title itself now lives ON the hero photo (see ``CookModeHero``), so this
/// row is just the two glyph buttons. They float in a `ZStack` above the step
/// ScrollView (see `CookModeView.body`) so they stay pinned even as the hero
/// scrolls away on a long step; each sits on a small circular scrim so it reads
/// over both a bright photo and the black step area below.
extension CookModeView {

    /// The floating back (leading) + ingredients (trailing) controls. They sit in
    /// the `ZStack` (which respects the top safe area), so a small top padding
    /// places them just under the status bar, on the hero's blur strip — no manual
    /// safe-area inset needed (adding one double-insets them into the photo).
    func cookModeTopBar() -> some View {
        HStack {
            floatingButton(
                systemName: "chevron.backward",
                label: "Exit Cook Mode",
                action: { close() }
            )
            .accessibilityIdentifier("cook-mode-close")

            Spacer()

            // DUT-599 successor — ingredients moved off the transport's carrot
            // button up here so the transport's play/pause can sit dead-center.
            floatingButton(
                systemName: "carrot.fill",
                label: "Show ingredients",
                action: { openIngredients() }
            )
            .accessibilityIdentifier("cook-mode-ingredients")
            .accessibilityValue(
                "\(viewModel.checkedIngredientIDs.count) of \(viewModel.recipe.ingredients.count) checked"
            )
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.top, DODSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    /// A circular glyph button for the floating hero controls, backed by Liquid
    /// Glass so it reads over any photo. A taller transparent frame gives the
    /// 44pt HIG tap target without enlarging the 34pt glass circle.
    private func floatingButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DODColor.burntOrange)
                .frame(width: 34, height: 34)
                .modifier(FloatingControlGlass())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Step counter (AC-7.2)
    //
    // The "Step X of Y" copy lives on `CookModeStepIndicator` at the bottom
    // (next to the progress bar). These strings are kept for any remaining
    // callers / tests.

    var stepCounterLabel: String {
        if viewModel.isFinished { return "Done" }
        return "Step \(viewModel.currentStepIndex + 1) of \(viewModel.stepCount)"
    }

    var stepCounterAccessibilityLabel: String {
        if viewModel.isFinished { return "Cooking complete" }
        return "Step \(viewModel.currentStepIndex + 1) of \(viewModel.stepCount)"
    }
}

/// Liquid Glass background for the floating hero controls (iOS 26+). Falls back
/// to a translucent black scrim circle on older OSes (the package deploys below
/// iOS 26), keeping the glyphs legible over any photo either way.
struct FloatingControlGlass: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Circle())
        } else {
            content.background(Circle().fill(.black.opacity(0.35)))
        }
        #else
        content.background(Circle().fill(.black.opacity(0.35)))
        #endif
    }
}

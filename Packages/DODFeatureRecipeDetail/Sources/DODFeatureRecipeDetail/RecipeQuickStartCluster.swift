import DODDesignSystem
import SwiftUI

/// DUT-572 / CL-312 — the quick-start cluster pinned at the top of the recipe,
/// composing the three things a cook wants first: the enhanced Cook Mode CTA
/// (full-width, from ``CookNowCTA``), then a row with the **Serves** scaler
/// (``RecipeServingsScaler``, reused verbatim) + a **"Jump to Instructions"**
/// capsule button.
///
/// Owns no state — the parent (`RecipeDetailView`) passes every input in, so it
/// keeps owning the servings binding, the cook-mode gate, and the jump proxy.
/// The Cook Mode CTA renders only when `showsCookMode` (preserves the AC-7.1
/// "hide until instructions parsed" gate).
struct RecipeQuickStartCluster: View {

    /// AC-7.1 gate — `!recipe.instructions.isEmpty`. When false, the CTA hides.
    let showsCookMode: Bool
    let onCookMode: () -> Void

    let servingsBinding: Binding<Int>
    let servingsRange: ClosedRange<Int>
    let sourceServings: Int
    let showsServingWarning: Bool

    let onJumpToInstructions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            if showsCookMode {
                CookNowCTA(onTap: onCookMode)
            }
            HStack(alignment: .top, spacing: DODSpacing.sm) {
                RecipeServingsScaler(
                    value: servingsBinding,
                    range: servingsRange,
                    sourceServings: sourceServings,
                    showsWarning: showsServingWarning
                )
                jumpButton
            }
        }
    }

    /// Styled like the old `RecipeDetailQuickJump` pill: caption text on a
    /// `surfaceElevated` capsule. Taps scroll the parent to the instructions
    /// anchor via the injected closure.
    private var jumpButton: some View {
        Button(action: onJumpToInstructions) {
            Text("Jump to Instructions")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.label)
                .padding(.horizontal, DODSpacing.sm)
                .padding(.vertical, DODSpacing.xs)
                .background(Capsule(style: .continuous).fill(DODColor.surfaceElevated))
        }
        .buttonStyle(.plain)
        .padding(.trailing, DODSpacing.md)
        .accessibilityHint("Jumps to Instructions section")
    }
}

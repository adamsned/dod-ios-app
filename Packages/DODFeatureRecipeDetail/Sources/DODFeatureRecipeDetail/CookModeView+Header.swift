import DODDesignSystem
import SwiftUI

/// Cook Mode header (DUT-325, redesigned DUT-582 / CL-315) — extracted from
/// `CookModeView.swift` so that file stays under the SwiftLint `file_length` cap.
///
/// DUT-582 layout: a **minimal** top bar — a close control (`chevron.down`) on
/// the leading edge, the recipe title small and centered, nothing else. The
/// voice/replay/speed controls moved into the player transport bar
/// (`CookModePlayerControls`) and the step counter moved to the bottom paged
/// indicator (`CookModeStepIndicator`), so this row is now just "get me out"
/// plus a quiet title — like the top of a now-playing screen.
extension CookModeView {

    /// The minimal Cook Mode top bar: close (leading) + a small centered title.
    var cookModeHeader: some View {
        ZStack {
            Text(viewModel.recipe.title)
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 56)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            HStack {
                closeButton
                Spacer()
            }
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.top, DODSpacing.sm)
        .padding(.bottom, DODSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(DODColor.surface)
    }

    /// Close (exit Cook Mode). A downward chevron reads as "dismiss this
    /// now-playing sheet", matching the music/podcast-player language.
    private var closeButton: some View {
        Button {
            close()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DODColor.burntOrange)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Exit Cook Mode")
    }

    // MARK: - Step counter (AC-7.2)
    //
    // The "Step X of Y" copy now lives on `CookModeStepIndicator` at the bottom
    // (DUT-582). These strings are kept for any remaining callers / tests.

    var stepCounterLabel: String {
        if viewModel.isFinished { return "Done" }
        return "Step \(viewModel.currentStepIndex + 1) of \(viewModel.stepCount)"
    }

    var stepCounterAccessibilityLabel: String {
        if viewModel.isFinished { return "Cooking complete" }
        return "Step \(viewModel.currentStepIndex + 1) of \(viewModel.stepCount)"
    }
}

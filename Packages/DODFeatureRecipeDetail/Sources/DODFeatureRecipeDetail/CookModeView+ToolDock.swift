import DODDesignSystem
import SwiftUI

/// DUT-1392 — Cook Mode's floating tool dock, composed from
/// ``CookModeToolDockContent``. Attached as the step ScrollView's bottom
/// `safeAreaInset`, so it floats right above the player controls, moves with
/// them as they minimize / expand, and the step text scrolls clear of it.
extension CookModeView {

    var toolDockContent: CookModeToolDockContent {
        CookModeToolDockContent.resolve(
            currentStepIndex: viewModel.currentStepIndex,
            stepText: viewModel.isFinished ? nil : viewModel.currentStep?.text,
            heatCoachAvailable: heatCoachSheet != nil,
            timers: viewModel.stepTimers,
            now: Date()
        )
    }

    @ViewBuilder
    var toolDock: some View {
        let content = toolDockContent
        if !content.isEmpty {
            VStack(spacing: DODSpacing.xs) {
                if let index = content.runningTimerStepIndex, let timer = viewModel.stepTimers[index] {
                    CookModeRunningTimerRow(stepIndex: index, timer: timer) {
                        wakeControls()
                        withAnimation(controlsAnimation) { viewModel.goToStep(index) }
                    }
                }
                if let duration = content.stepTimerDuration {
                    CookTimer(stepIndex: viewModel.currentStepIndex, duration: duration, viewModel: viewModel)
                }
                if content.showsHeatCoach {
                    CookModeHeatCoachRow { isHeatCoachPresented = true }
                }
            }
            // Floats over the scrolling step text.
            .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 6)
            .frame(maxWidth: toolDockMaxWidth)
            .padding(.horizontal, DODSpacing.md)
            .padding(.bottom, DODSpacing.sm)
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cook-mode-tool-dock")
        }
    }

    /// A comfortable dock width on iPad's wide canvas; full width on iPhone.
    private var toolDockMaxWidth: CGFloat { isPadIdiom ? 640 : .infinity }
}

import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-137 — iPad regular-width two-pane Cook Mode. The pinned right pane keeps
/// the tool dock (running timers / step timer / Heat Coach) live while the left
/// pane's step text changes with navigation.
extension CookModeView {

    /// Pinned right pane: reuses the tool dock content so timers keep ticking
    /// across step changes.
    @ViewBuilder
    var pinnedPane: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            toolDock
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .animation(controlsAnimation, value: toolDockContent)
        .accessibilityIdentifier("cook-mode-pinned-pane")
        .dynamicTypeSize(.accessibility3)
    }

    /// The scrolling step area (hero, Ask link, rescue link, step body). The
    /// bottom tool dock inset is shown only in the stacked layout; in two-pane it
    /// lives in `pinnedPane`.
    func stepScroll(topInset: CGFloat, showsToolDock: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                // DUT-1392 — "Ask About This Recipe" sits right under the recipe name.
                VStack(alignment: .leading, spacing: DODSpacing.xs) {
                    heroView(topInset: topInset)
                    askAboutRecipeLink
                    Button {
                        wakeControls()
                        isRescuePresented = true
                    } label: {
                        Label("Something not going right?", systemImage: "lifepreserver")
                            .dodFont(DODType.bodyEmphasized)
                            .foregroundStyle(DODColor.accent)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DODSpacing.md)
                    .accessibilityIdentifier("cook-mode-rescue")
                    .accessibilityHint("Quick fixes for sticking, heat and other cooking problems")
                }
                stepBody
            }
            .padding(.bottom, DODSpacing.md)
        }
        .ignoresSafeArea(.container, edges: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsToolDock { toolDock }
        }
        .animation(controlsAnimation, value: toolDockContent)
        // DUT-596/599 — a tap in the collapsed step area brings the controls back;
        // a no-op while expanded so it never fights reading.
        .contentShape(Rectangle())
        .onTapGesture { if !controlsExpanded { wakeControls() } }
    }
}

extension CookModeLayout {
    /// Pinned pane width clamped so Stage Manager's smallest regular windows still
    /// leave the step pane at least 320pt and the pinned pane at least 280pt.
    static func clampedPinnedPaneWidth(containerWidth: CGFloat) -> CGFloat {
        let ideal = pinnedPaneWidth(containerWidth: containerWidth)
        let maxPane = max(280, containerWidth - 320)
        return min(max(ideal, 280), maxPane)
    }
}

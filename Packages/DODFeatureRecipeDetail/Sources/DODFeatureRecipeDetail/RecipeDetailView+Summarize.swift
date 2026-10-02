import DODDesignSystem
import SwiftUI

// DUT-1386 — the on-device "Summarize" affordance moved out of the toolbar
// (where it was an unlabeled sparkle icon) to a labeled "Summarize" link right
// under the recipe/article header. Lives in its own file because
// `RecipeDetailView.swift` is at the SwiftLint length cap.
extension RecipeDetailView {

    /// The first rows under the hero: the Summarize link (only when the
    /// on-device model is usable and there is cached text to summarize — absent,
    /// never disabled, everywhere else), then the publish date + Jump row.
    func headerRow(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            if let summarizeAction {
                SummarizeButton(action: summarizeAction)
                    .padding(.horizontal, DODSpacing.md)
            }
            dateAndJumpRow(proxy: proxy)
        }
    }

    /// Runs the on-device summary for the open recipe or article, or `nil` when
    /// summarizing isn't possible right now (no model, nothing cached). Shared by
    /// the recipe header and ``ArticleDetailView``. The summary sheet itself is
    /// still presented from the toolbar content (see `+Toolbar`).
    var summarizeAction: (() -> Void)? {
        guard viewModel.isSummaryAvailable, !viewModel.summaryBodyText.isEmpty else { return nil }
        return { Task { await viewModel.requestSummary() } }
    }
}

/// DUT-1386 — the labeled sparkle "Summarize" link shown under the recipe and
/// article headers: plain accent text + icon, no background shape (same inline
/// style family as "Jump to Instructions").
struct SummarizeButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Summarize", systemImage: "sparkles")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.accent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dod.detail.summary.button")
        .accessibilityHint("Summarizes this on your device with Apple Intelligence")
    }
}

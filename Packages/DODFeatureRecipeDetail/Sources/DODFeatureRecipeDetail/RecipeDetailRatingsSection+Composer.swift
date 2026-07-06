import DODDesignSystem
import SwiftUI

// The consolidated rate + review composer sub-views for
// ``RecipeDetailRatingsSection`` — the comment editor, the DUT-605 character
// counter, and the single Submit control. Extracted from the section's main
// file so it stays under the SwiftLint 400-line `file_length` cap (same
// extraction pattern as `+PhaseD.swift`).

extension RecipeDetailRatingsSection {

    /// Optional inline comment editor (AC-14.3). Empty is valid — the user
    /// can submit a star rating alone. Styling matches the DesignSystem
    /// `CommentComposer` editor (bordered `TextEditor` + placeholder) so the
    /// look is unchanged from the old composer, minus its duplicate stars.
    var commentField: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Add a comment (optional)")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .stroke(DODColor.labelSecondary.opacity(0.25), lineWidth: 1)

                TextEditor(
                    text: Binding(
                        get: { viewModel.commentDraft },
                        set: { viewModel.setCommentDraft($0) }
                    )
                )
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .scrollContentBackground(.hidden)
                .padding(DODSpacing.xs)
                .frame(minHeight: 120)
                .disabled(viewModel.isSubmittingRatingOrComment)
                .accessibilityLabel("Comment (optional)")

                if viewModel.commentDraft.isEmpty {
                    Text("Share your tips, substitutions, or thoughts.")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.labelSecondary.opacity(0.7))
                        .padding(.horizontal, DODSpacing.sm)
                        .padding(.vertical, DODSpacing.sm + 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            // DUT-605: live character counter + a defensive clamp. The VM setter
            // already caps the draft, but `.onChange` re-clamps in case any path
            // (e.g. a system autofill) mutates the binding without routing through
            // the setter. Gating the Submit on the same cap lives in the VM.
            commentCharacterCounter
        }
        .onChange(of: viewModel.commentDraft) { _, newValue in
            let limit = RecipeDetailViewModel.commentDraftCharacterLimit
            if newValue.count > limit {
                viewModel.setCommentDraft(String(newValue.prefix(limit)))
            }
        }
    }

    /// DUT-605 — "N / 1000" counter under the comment editor. Turns to the
    /// warning tint at the cap so the user sees they've hit the limit.
    var commentCharacterCounter: some View {
        let limit = RecipeDetailViewModel.commentDraftCharacterLimit
        let count = viewModel.commentDraft.count
        return Text("\(count) / \(limit)")
            .dodFont(DODType.caption)
            .foregroundStyle(count >= limit ? DODColor.accent : DODColor.labelSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("\(count) of \(limit) characters used")
    }

    /// The one and only Submit control for the section. Enabled when the
    /// user has set a rating OR typed a comment AND the on-form name + email
    /// are valid (DUT-28). One tap persists the identity and posts.
    var submitButton: some View {
        Button {
            Task { await viewModel.submitRatingAndComment() }
        } label: {
            Text(viewModel.isSubmittingRatingOrComment ? "Submitting…" : "Submit")
                .dodFont(DODType.bodyEmphasized)
                .padding(.horizontal, DODSpacing.lg)
                .padding(.vertical, DODSpacing.sm)
        }
        .dodProminentButton()
        .tint(DODColor.accent)
        .disabled(!viewModel.canSubmitRatingOrComment || viewModel.isSubmittingRatingOrComment)
        .accessibilityLabel("Submit rating and review")
    }
}

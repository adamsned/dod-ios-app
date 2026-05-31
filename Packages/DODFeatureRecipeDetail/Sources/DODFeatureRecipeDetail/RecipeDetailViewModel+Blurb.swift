import DODSupport

/// T-733 / CL-130: ``RecipeDetailViewModel`` blurb-visibility computed
/// property. Extracted into its own file so the main view-model type stays
/// under SwiftLint's `file_length` cap.
///
/// Spec trace: AC-4.12 (amended), CL-130, REG-33.
extension RecipeDetailViewModel {

    /// True when ``blurbBlocks`` contains at least one `.paragraph` case —
    /// the More/Less visibility gate. Broadens T-732's pre-CL-130
    /// `!blurbBlocks.isEmpty` gate so a recipe whose pre-WPRM content is
    /// only a heading / image / list (no narrative paragraph) correctly
    /// gets no More button — there'd be nothing meaningful to expand into.
    /// Pure computation off ``blurbBlocks``; no separate stored state to
    /// keep in sync.
    public var hasExpandableBlurb: Bool {
        blurbBlocks.contains { block in
            if case .paragraph = block { return true }
            return false
        }
    }
}

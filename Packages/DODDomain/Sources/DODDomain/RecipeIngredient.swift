import Foundation

/// One ingredient line from JSON-LD `recipeIngredient`.
/// Stored as raw text; the JSON-LD shape has no per-ingredient ID.
/// Spec trace: spec.md AC-4.2.
public struct RecipeIngredient: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public let text: String

    /// DUT-641: `id` now derives DETERMINISTICALLY from `text` when the caller
    /// doesn't pass one (was a fresh random `UUID()` per call). Ingredient
    /// check-state (`RecipeDetailViewModel.checkedIngredientIDs`, keyed on
    /// `id`) used to clear whenever a recipe re-parsed mid-session, because the
    /// same line parsed to a brand-new random id each time. A stable text-
    /// derived id keeps the check-state stable across re-parses.
    ///
    /// The memberwise signature is source-compatible: callers may still pass an
    /// explicit `id:` (which wins) via ``init(id:text:)``; the common
    /// `RecipeIngredient(text:)` call site now gets the deterministic id.
    public init(text: String) {
        self.id = DeterministicUUID.from(text)
        self.text = text
    }

    /// Explicit-id init (unchanged behaviour). Kept so existing call sites that
    /// pass `id:` — e.g. Codable decode, fixtures — still compile and honour the
    /// supplied id rather than re-deriving it.
    public init(id: UUID, text: String) {
        self.id = id
        self.text = text
    }
}

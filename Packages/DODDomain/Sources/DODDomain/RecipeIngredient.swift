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

    /// DUT-705: index-aware init. `init(text:)` derives `id` from `text` alone,
    /// so a legitimately repeated ingredient line (e.g. "Salt" in two
    /// sub-sections) collides on one `id` — checking one line then toggles all
    /// identical lines and `ForEach` sees duplicate identities. Folding the
    /// line's positional `index` into the deterministic hash keeps ids stable
    /// across re-parses (DUT-641) while making equal text at different
    /// positions distinct. The `U+0001` separator can't occur in real
    /// ingredient text, so it can't be forged by the text itself.
    public init(text: String, index: Int) {
        self.id = DeterministicUUID.from("\(index)\u{1}\(text)")
        self.text = text
    }

    /// Explicit-id init (unchanged behaviour). Kept so existing call sites that
    /// pass `id:` — e.g. Codable decode, fixtures — still compile and honour the
    /// supplied id rather than re-deriving it.
    public init(id: UUID, text: String) {
        self.id = id
        self.text = text
    }

    /// DUT-705: build a list of ingredients from raw text lines, salting each
    /// line's deterministic `id` with its positional index so duplicate lines
    /// get distinct-but-stable ids. Parse call sites should use this instead of
    /// `texts.map { RecipeIngredient(text: $0) }`.
    public static func list(from texts: [String]) -> [RecipeIngredient] {
        texts.enumerated().map { RecipeIngredient(text: $0.element, index: $0.offset) }
    }
}

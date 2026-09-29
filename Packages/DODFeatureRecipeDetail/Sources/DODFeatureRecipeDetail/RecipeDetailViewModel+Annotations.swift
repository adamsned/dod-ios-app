import DODPersistence
import Foundation

/// Per-recipe handwritten-annotation load/save seam (iPad + Apple Pencil, v2).
///
/// Keys on `listItem.id` — the WordPress post id — which is always available
/// (unlike `recipe`, which is `nil` until the detail load resolves), so an
/// annotation saved for a recipe reliably reloads on the next visit. The
/// drawing crosses as Foundation-only ``RecipeAnnotationRecord`` bytes; the
/// `PKDrawing` ⇄ `Data` conversion is the view layer's job (iOS-guarded).
extension RecipeDetailViewModel {

    /// The recipe id used to key annotation persistence.
    var annotationRecipeID: Int { listItem.id }

    /// Load this recipe's saved annotation, or `nil` if none exists.
    func loadAnnotation() async -> RecipeAnnotationRecord? {
        await dependencies.loadRecipeAnnotation(recipeID: annotationRecipeID)
    }

    /// Persist this recipe's annotation (best-effort; errors are swallowed
    /// inside the dependency's live impl — the drawing UI never blocks on I/O).
    func saveAnnotation(_ record: RecipeAnnotationRecord) async {
        await dependencies.saveRecipeAnnotation(record, recipeID: annotationRecipeID)
    }
}

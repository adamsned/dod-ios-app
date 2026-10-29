import DODPersistence
import Foundation

// Per-recipe handwritten-annotation persistence (iPad + Apple Pencil, v2).
//
// The seam is declared on ``RecipeDetailDependencies``; the drawing crosses it
// as Foundation-only ``RecipeAnnotationRecord`` bytes so no PencilKit type
// leaks into the (macOS-buildable) dependency layer. Default impls are safe
// no-ops so every existing fake keeps compiling without opting in;
// ``LiveRecipeDetailDependencies`` overrides to route to a file-backed
// ``FileRecipeAnnotationStore``.

extension RecipeDetailDependencies {

    /// Default no-op — a fake that doesn't model annotations reads back `nil`.
    public func loadRecipeAnnotation(recipeID: Int) async -> RecipeAnnotationRecord? {
        nil
    }

    /// Default no-op — a fake that doesn't model annotations drops the write.
    public func saveRecipeAnnotation(_ record: RecipeAnnotationRecord, recipeID: Int) async {}
}

extension LiveRecipeDetailDependencies {

    /// The production annotation store — one JSON file per recipe under
    /// Application Support/RecipeAnnotations. Stateless (just a directory URL),
    /// so it's created on demand rather than threaded through the (already
    /// large) initializer.
    private var annotationStore: any RecipeAnnotationStoring {
        FileRecipeAnnotationStore()
    }

    public func loadRecipeAnnotation(recipeID: Int) async -> RecipeAnnotationRecord? {
        annotationStore.annotation(forRecipeID: recipeID)
    }

    public func saveRecipeAnnotation(_ record: RecipeAnnotationRecord, recipeID: Int) async {
        try? annotationStore.save(record, forRecipeID: recipeID)
    }
}

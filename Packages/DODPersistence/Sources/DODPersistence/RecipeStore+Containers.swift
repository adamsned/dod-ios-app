import DODDomain
import Foundation
import SwiftData

// MARK: - Container construction
//
// Extracted from RecipeStore.swift to keep that file under the
// SwiftLint 400-line file_length cap after T-620 (downloadedAt) and
// T-640 (articleBodyHTML / PostKind) both added persistence surface.
// No behavior change — these were already extension methods on
// `RecipeStore` in the main file.

extension RecipeStore {

    /// Create the on-disk container for production use. Pinned to the
    /// latest schema (`SchemaV3`) — older on-disk stores get migrated via
    /// `MigrationPlan` at open (V1 → V2 → V3, all lightweight). The
    /// `articleBodyHTML` optional column added for US-37 / CL-63 / T-640
    /// is an in-place additive optional property on `CachedRecipe`; see
    /// `SchemaV4.swift` for the rationale on why it's not a separate
    /// schema stage.
    public static func productionContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV3.models),
            migrationPlan: MigrationPlan.self,
            configurations: ModelConfiguration()
        )
    }

    /// Create an in-memory container for tests. Uses the current schema so
    /// fixture data exercises the same models the app ships with.
    public static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV3.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Create an in-memory container at the legacy V1 schema. Used only by
    /// the V1→V2 migration test to prove a pre-US-12 store opens cleanly
    /// under V2. Production code never calls this.
    public static func inMemoryContainerV1() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Create an in-memory container at the V2 schema. Used only by the
    /// V2→V3 migration test to prove a pre-US-13/14 store opens cleanly
    /// under V3. Production code never calls this.
    public static func inMemoryContainerV2() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV2.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

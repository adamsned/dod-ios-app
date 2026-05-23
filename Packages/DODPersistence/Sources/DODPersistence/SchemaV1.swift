import Foundation
import SwiftData

/// Schema V1 — the initial persistent shape shipped in v1.0.
///
/// **Migration rule (R-5):** future schema changes are additive-only.
/// Never delete or rename a stored field on a `@Model`; always add a new
/// optional field and migrate values lazily. The migration plan template
/// in ``MigrationPlan`` enforces this discipline.
public enum SchemaV1: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [CachedRecipe.self, CachedListPage.self, CachedImage.self]
    }
}

/// Migration plan. Currently single-version; new VersionedSchema cases get
/// added here and bridged with `MigrationStage.custom` / `.lightweight`.
public enum MigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}

import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// L1 coverage for the DUT-6 container-configuration selection — the
/// persisted opt-in flag as the single source of truth, the config branch
/// that matches it, and the DOD-CRASH-1-safe production-container build.
///
/// These pin the contract the DUT-6 fix relies on: the flag is read at
/// launch, the container is built with/without the CloudKit option to
/// match, and the opt-out path never touches CloudKit (REG-25 / AC-41.1).
@Suite("CloudKit container selection (DUT-6)")
struct CloudKitContainerSelectionTests {

    /// Per-test isolated suite so the shared `.standard` defaults stay
    /// clean across the run. Mirrors `SettingsViewModelTests.isolatedDefaults`.
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "CloudKitContainerSelectionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Flag as single source of truth

    @Test func optInReaderDefaultsToFalseForAbsentKey() {
        let defaults = Self.isolatedDefaults()
        // A fresh install / never-prompted user reads OFF — the AC-41.1
        // graceful-fallback starting state.
        #expect(RecipeStore.cloudKitSyncOptIn(in: defaults) == false)
    }

    /// DUT-493 — the durable backfill-complete reader `RecipeStore` seeds its
    /// in-memory flag from at construction (so the DUT-470 provisional union
    /// doesn't open its pre-`bootstrap()` window for a completed-backfill user).
    @Test func backfillDidCompleteReaderReflectsPersistedFlag() {
        let defaults = Self.isolatedDefaults()
        #expect(RecipeStore.backfillDidComplete(in: defaults) == false)  // absent → not complete
        defaults.set(true, forKey: RecipeStore.didBackfillSyncedSavedKey)
        #expect(RecipeStore.backfillDidComplete(in: defaults) == true)
        defaults.set(false, forKey: RecipeStore.didBackfillSyncedSavedKey)
        #expect(RecipeStore.backfillDidComplete(in: defaults) == false)
    }

    @Test func optInReaderReflectsPersistedFlag() {
        let defaults = Self.isolatedDefaults()
        defaults.set(true, forKey: RecipeStore.cloudKitSyncOptInKey)
        #expect(RecipeStore.cloudKitSyncOptIn(in: defaults) == true)
        defaults.set(false, forKey: RecipeStore.cloudKitSyncOptInKey)
        #expect(RecipeStore.cloudKitSyncOptIn(in: defaults) == false)
    }

    // MARK: - Configuration branch matches the flag (REG-25 / AC-41.1)

    @Test func optOutConfigurationNeverTouchesCloudKit() throws {
        // Drive the shared-defaults read path the production factory uses.
        let defaults = UserDefaults.standard
        let prior = defaults.object(forKey: RecipeStore.cloudKitSyncOptInKey)
        defaults.set(false, forKey: RecipeStore.cloudKitSyncOptInKey)
        defer {
            if let prior {
                defaults.set(prior, forKey: RecipeStore.cloudKitSyncOptInKey)
            } else {
                defaults.removeObject(forKey: RecipeStore.cloudKitSyncOptInKey)
            }
        }
        let configuration = RecipeStore.makeProductionConfiguration()
        // The plain configuration carries no CloudKit container identifier.
        #expect(configuration.cloudKitContainerIdentifier == nil)
    }

    // MARK: - DOD-CRASH-1-safe production container build

    @Test func optOutBuildProducesPlainContainerWithoutFallback() throws {
        let defaults = Self.isolatedDefaults()
        defaults.set(false, forKey: RecipeStore.cloudKitSyncOptInKey)
        // The opt-out path builds a plain local container and never reports
        // the CloudKit fallback (there was no CloudKit attempt to fall back
        // from). It must open cleanly — the same path every non-synced user
        // hits on launch. Built in-memory so the test never touches the
        // shared on-disk store.
        let result = try RecipeStore.productionContainer(defaults: defaults, inMemory: true)
        #expect(result.usedCloudKitFallback == false)
        // Sanity: the container is usable for a basic insert/read.
        let context = ModelContext(result.container)
        context.insert(
            CachedRecipe(
                id: 7,
                slug: "s",
                title: "T",
                excerptText: "e",
                canonicalURLString: "https://example.com/7",
                publishedAt: .now
            )
        )
        try context.save()
        let rows = try context.fetch(
            FetchDescriptor<CachedRecipe>(predicate: #Predicate { $0.id == 7 })
        )
        #expect(rows.count == 1)
    }

    @Test func cloudKitBuildFailureFallsBackToLocalContainer() throws {
        // DOD-CRASH-1 defense-in-depth, exercised by injection: a real
        // `.private` `NSPersistentCloudKitContainer` open can't be made to
        // throw hermetically in a unit-test process (it needs the app's
        // CloudKit/push entitlements; in-memory `.private` opens actually
        // succeed here), so we drive the throwing CloudKit-build branch
        // directly. The contract: on a thrown CloudKit error, degrade to the
        // local container and report `usedCloudKitFallback == true` — NEVER
        // rethrow up to `AppDependencies.init`'s `fatalError`. This is the
        // exact path that keeps a never-deployed-Production-schema TestFlight
        // build launchable instead of crash-looping.
        struct CloudKitOpenFailed: Error {}
        let localContainer = try RecipeStore.inMemoryContainer()
        let result = try RecipeStore.buildCloudKitWithFallback(
            cloudKitBuild: { throw CloudKitOpenFailed() },
            localBuild: { localContainer }
        )
        #expect(result.usedCloudKitFallback == true)
        #expect(result.container === localContainer)
    }

    @Test func cloudKitBuildSuccessDoesNotUseFallback() throws {
        // When the CloudKit build succeeds, the fallback never fires and the
        // returned container is the CloudKit one.
        let cloudKitContainer = try RecipeStore.inMemoryContainer()
        let result = try RecipeStore.buildCloudKitWithFallback(
            cloudKitBuild: { cloudKitContainer },
            localBuild: {
                Issue.record("local fallback must not be built on success")
                return cloudKitContainer
            }
        )
        #expect(result.usedCloudKitFallback == false)
        #expect(result.container === cloudKitContainer)
    }
}

import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// L1 coverage for the DUT-78 crash-loop self-heal + pre-open account-status
/// guard (T-791). These pin the pure logic the device fix relies on so CI
/// validates it without a device, an iCloud account, or the async CloudKit
/// mirroring path that can only be reproduced on a real device/sim:
///
/// - the ``LaunchHealthTracker`` consecutive-unhealthy-launch state machine
///   (the self-heal escape hatch);
/// - the ``CloudKitAvailability`` "attempt CloudKit vs fall back" decision
///   given an injected account status (the pre-open guard);
/// - the `productionContainer(defaults:accountStatus:launchHealth:)` branch
///   that opens local — never `.private(...)` — when either guard says so,
///   plus the tainted-store flag.
@Suite("CloudKit crash-loop self-heal (DUT-78 / T-791)")
struct CloudKitCrashLoopSelfHealTests {

    /// Per-test isolated `UserDefaults` so the self-heal counter / cached
    /// status / opt-in flag never leak across tests or into `.standard`.
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "CloudKitCrashLoopSelfHealTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - LaunchHealthTracker state machine

    @Test func freshInstallHasZeroUnhealthyLaunchesAndDoesNotHeal() {
        let tracker = LaunchHealthTracker(defaults: Self.isolatedDefaults())
        #expect(tracker.unhealthyLaunchCount == 0)
        #expect(tracker.shouldSelfHeal == false)
    }

    @Test func recordLaunchStartedIncrementsAndReturnsCount() {
        let defaults = Self.isolatedDefaults()
        let tracker = LaunchHealthTracker(defaults: defaults)
        #expect(tracker.recordLaunchStarted() == 1)
        #expect(tracker.recordLaunchStarted() == 2)
        #expect(tracker.unhealthyLaunchCount == 2)
    }

    @Test func markLaunchHealthyResetsCounter() {
        let defaults = Self.isolatedDefaults()
        let tracker = LaunchHealthTracker(defaults: defaults)
        tracker.recordLaunchStarted()
        tracker.recordLaunchStarted()
        tracker.markLaunchHealthy()
        #expect(tracker.unhealthyLaunchCount == 0)
        #expect(tracker.shouldSelfHeal == false)
    }

    @Test func selfHealTripsExactlyAtTheLimit() {
        let defaults = Self.isolatedDefaults()
        let tracker = LaunchHealthTracker(defaults: defaults)
        // Simulate N consecutive crash-looping launches: each launch records
        // started but crashes before marking healthy.
        for attempt in 1..<LaunchHealthTracker.unhealthyLaunchLimit {
            tracker.recordLaunchStarted()
            #expect(tracker.shouldSelfHeal == false, "must not heal at \(attempt) (< limit)")
        }
        // The launch that pushes the count to the limit is the one that heals.
        tracker.recordLaunchStarted()
        #expect(tracker.unhealthyLaunchCount == LaunchHealthTracker.unhealthyLaunchLimit)
        #expect(tracker.shouldSelfHeal == true)
    }

    @Test func aHealthyLaunchBetweenCrashesPreventsHealing() {
        // A real crash-loop is *consecutive*; a single healthy launch resets.
        let defaults = Self.isolatedDefaults()
        let tracker = LaunchHealthTracker(defaults: defaults)
        tracker.recordLaunchStarted()
        tracker.recordLaunchStarted()
        tracker.markLaunchHealthy()  // app came up once
        tracker.recordLaunchStarted()
        #expect(tracker.shouldSelfHeal == false)
    }

    // MARK: - CloudKitAvailability decision

    @Test func onlyAvailableAccountAttemptsCloudKit() {
        #expect(CloudKitAvailability.shouldAttemptCloudKit(given: .available) == true)
        for status: CloudKitAvailability.AccountStatus in [.noAccount, .restricted, .couldNotDetermine, .unknown] {
            #expect(
                CloudKitAvailability.shouldAttemptCloudKit(given: status) == false,
                "status \(status) must NOT attempt CloudKit (DUT-78 async-trap avoidance)"
            )
        }
    }

    @Test func cachedAccountStatusRoundTrips() {
        let defaults = Self.isolatedDefaults()
        #expect(CloudKitAvailability.cachedAccountStatus(in: defaults) == nil)
        CloudKitAvailability.cacheAccountStatus(.noAccount, in: defaults)
        #expect(CloudKitAvailability.cachedAccountStatus(in: defaults) == .noAccount)
        CloudKitAvailability.cacheAccountStatus(.available, in: defaults)
        #expect(CloudKitAvailability.cachedAccountStatus(in: defaults) == .available)
    }

    // MARK: - Container build honors both guards (opens local, not .private)

    @Test func unavailableAccountOpensLocalWithFallbackFlag() throws {
        let defaults = Self.isolatedDefaults()
        defaults.set(true, forKey: RecipeStore.cloudKitSyncOptInKey)
        // Opt-in is ON, but the cached account status says "no account" — the
        // pre-open guard must open local (never `.private(...)`) and report the
        // fallback, so the async mirroring trap is dodged. In-memory so the
        // test never touches the on-disk store.
        let result = try RecipeStore.productionContainer(
            defaults: defaults,
            accountStatus: .noAccount,
            launchHealth: nil,
            inMemory: true
        )
        #expect(result.usedCloudKitFallback == true)
        #expect(result.didSelfHeal == false)
        try expectContainerUsable(result.container)
    }

    @Test func availableAccountOnOptInDoesNotForceFallback() throws {
        let defaults = Self.isolatedDefaults()
        defaults.set(true, forKey: RecipeStore.cloudKitSyncOptInKey)
        // Account available + opt-in ON: the guard does NOT short-circuit to
        // local — control reaches the CloudKit-attempt branch (the decision
        // under test). The container is built in-memory, which forces
        // `cloudKitDatabase: .none` (an in-memory `.private` open spins up
        // NSCloudKitMirroringDelegate → PushKit and aborts a test host with no
        // CloudKit entitlement — SIGABRT), so this exercises the branch
        // SELECTION without opening a real CloudKit container. The actual
        // synchronous `.private` open + its DOD-CRASH-1 catch are
        // device-verified, not unit-tested.
        let result = try RecipeStore.productionContainer(
            defaults: defaults,
            accountStatus: .available,
            launchHealth: nil,
            inMemory: true
        )
        #expect(result.didSelfHeal == false)
        try expectContainerUsable(result.container)
    }

    @Test func selfHealForcesLocalAndFlagsDidSelfHeal() throws {
        let defaults = Self.isolatedDefaults()
        defaults.set(true, forKey: RecipeStore.cloudKitSyncOptInKey)
        // Drive the tracker to the heal threshold, then build: even with the
        // account "available", the self-heal hatch wins and forces local.
        let tracker = LaunchHealthTracker(defaults: defaults)
        for _ in 0..<LaunchHealthTracker.unhealthyLaunchLimit {
            tracker.recordLaunchStarted()
        }
        let result = try RecipeStore.productionContainer(
            defaults: defaults,
            accountStatus: .available,
            launchHealth: tracker,
            inMemory: true
        )
        #expect(result.usedCloudKitFallback == true)
        #expect(result.didSelfHeal == true)
        try expectContainerUsable(result.container)
    }

    @Test func optOutNeverSelfHealsOrFallsBack() throws {
        let defaults = Self.isolatedDefaults()
        defaults.set(false, forKey: RecipeStore.cloudKitSyncOptInKey)
        // Even a tracker past the heal threshold doesn't matter when sync is
        // OFF — the opt-out path opens local cleanly and reports neither flag.
        let tracker = LaunchHealthTracker(defaults: defaults)
        for _ in 0..<LaunchHealthTracker.unhealthyLaunchLimit {
            tracker.recordLaunchStarted()
        }
        let result = try RecipeStore.productionContainer(
            defaults: defaults,
            accountStatus: .noAccount,
            launchHealth: tracker,
            inMemory: true
        )
        #expect(result.usedCloudKitFallback == false)
        #expect(result.didSelfHeal == false)
        try expectContainerUsable(result.container)
    }

    @Test func legacyEntryPointMatchesPreDUT78Behavior() throws {
        // The thin `productionContainer(defaults:inMemory:)` wrapper passes no
        // probe + no tracker, so it behaves exactly as before DUT-78: opt-out
        // opens local with no fallback.
        let defaults = Self.isolatedDefaults()
        defaults.set(false, forKey: RecipeStore.cloudKitSyncOptInKey)
        let result = try RecipeStore.productionContainer(defaults: defaults, inMemory: true)
        #expect(result.usedCloudKitFallback == false)
        #expect(result.didSelfHeal == false)
    }

    // MARK: - Helpers

    /// Sanity that a built container supports a basic insert/read, mirroring
    /// `CloudKitContainerSelectionTests`.
    private func expectContainerUsable(_ container: ModelContainer) throws {
        let context = ModelContext(container)
        context.insert(
            CachedRecipe(
                id: 78,
                slug: "s",
                title: "T",
                excerptText: "e",
                canonicalURLString: "https://example.com/78",
                publishedAt: .now
            )
        )
        try context.save()
        let rows = try context.fetch(
            FetchDescriptor<CachedRecipe>(predicate: #Predicate { $0.id == 78 })
        )
        #expect(rows.count == 1)
    }
}

import Foundation

/// DUT-943 Scope A: serializes the small set of tests that build a REAL
/// on-disk `ModelContainer` from an explicit historical `Schema(SchemaVn...)`
/// literal (rather than going through `RecipeStore.inMemoryContainer()`,
/// which every other test in this target safely shares because it always
/// resolves to whatever schema is "current").
///
/// `@Suite(.serialized)` only serializes a suite's OWN children — it does NOT
/// stop a DIFFERENT suite's on-disk-container test from running at the same
/// time. Concurrently opening containers that disagree on which schema
/// version is "current" for the SAME `@Model` Swift classes corrupts
/// SwiftData's shared `NSEntityDescription` registration and crashes the
/// whole test process ("Can't assign an object to a store that does not
/// contain the object's entity").
///
/// Confirmed by bisection: adding DUT-943 Scope A's
/// `SchemaV7Tests.v6OnDiskStoreUpgradesToV7PreservingSaves` (a THIRD instance
/// of the "build an old-version on-disk store, then reopen it under a newer
/// declared-current schema" pattern, after `SchemaV5Tests`'s V4 -> V5 test and
/// `RecipeEditorialColumnsTests`'s reopen-through-the-plan test) reliably
/// reproduced the crash in this test target; wrapping all three call sites in
/// this shared lock reliably fixes it. Production only ever opens ONE
/// container per process, so this lock has no relevance outside the test
/// process — it exists purely to work around this swift-testing /
/// SwiftData interaction.
enum OnDiskSchemaContainerTestLock {
    private static let lock = NSLock()

    /// Runs `body` with the shared lock held, so at most one on-disk
    /// version-specific container is under construction anywhere in this
    /// test target at a time. `body` is synchronous — every current call
    /// site is a plain `throws` (non-`async`) test — so a simple `NSLock`
    /// is sufficient with no risk of blocking the cooperative thread pool
    /// across an `await`.
    static func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

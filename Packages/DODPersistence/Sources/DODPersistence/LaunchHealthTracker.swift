import Foundation

/// Self-heal escape hatch for the DUT-78 CloudKit launch crash-loop.
///
/// **The bug it guards (DUT-78).** Enabling iCloud Sync opens the
/// `SyncedSaved` store with `.private(...)`. On a device/sim where the
/// CloudKit container can't initialize (not signed into iCloud, Production
/// schema not provisioned), Core Data's CloudKit mirroring setup traps with
/// `EXC_BREAKPOINT` on `com.apple.coredata.cloudkit.queue` — **asynchronously,
/// after** the synchronous `ModelContainer(...)` open already returned. The
/// existing `buildCloudKitWithFallback` only wraps the *synchronous* open in
/// do/catch, so it never catches that async trap; the app crash-loops on every
/// relaunch and (because the on-disk store stays tainted) even flipping the
/// opt-in flag back off doesn't recover it. Only a reinstall did.
///
/// **What this type does.** It is the last-resort safety net the
/// `CKContainer.accountStatus` pre-flight guard (``CloudKitAvailability``) and
/// tainted-store rebuild can't cover — a brand-new failure mode that still
/// traps before any of those run. At the *very start* of every launch the host
/// records "a launch started but hasn't been marked healthy yet" by
/// incrementing a persisted counter; once the app reaches a known-good point
/// (the SwiftUI scene is on screen and the first run loop turned over) it calls
/// ``markLaunchHealthy()`` to reset the counter to zero. A launch that crashes
/// before `markLaunchHealthy()` therefore leaves the counter incremented. After
/// ``unhealthyLaunchLimit`` consecutive unhealthy launches, ``shouldSelfHeal``
/// returns `true` and the host force-disables the CloudKit opt-in flag and
/// opens a plain local container — so the app becomes launchable again and the
/// user can reach Settings, instead of being stuck reinstalling.
///
/// **Why a value/`UserDefaults` type (no SwiftData / no UIKit).** The whole
/// state machine is plain `Int` bookkeeping over an injectable
/// `UserDefaults`, so the L1 suite drives every branch on macOS under
/// `swift test` without a device, a CloudKit account, or the SwiftData macro
/// plugin (DUT-78 / T-791). The host owns the *timing* of the three calls
/// (`recordLaunchStarted` first, `markLaunchHealthy` when on screen,
/// `shouldSelfHeal` consulted at container-build time); this type owns only
/// the counter arithmetic and the threshold decision.
public struct LaunchHealthTracker: Sendable {

    /// `UserDefaults` key for the consecutive-unhealthy-launch counter
    /// (DUT-78). Versioned (`V1`) so a future schema change to the self-heal
    /// bookkeeping can migrate cleanly without colliding with this key.
    public static let unhealthyLaunchCountKey = "dod.cloudkit.unhealthyLaunchCountV1"

    /// Number of consecutive unhealthy (started-but-never-marked-healthy)
    /// launches after which the host force-disables the CloudKit opt-in and
    /// opens local (DUT-78). Three balances "don't nuke sync on a single
    /// unrelated crash" against "don't leave the user stuck reinstalling":
    /// the very first crash-looping launch already increments to 1, so by the
    /// fourth attempt the counter has reached 3 and the self-heal trips,
    /// bounding the crash-loop the user actually sees to a few launches.
    public static let unhealthyLaunchLimit = 3

    private let defaults: UserDefaults

    /// Inject the backing `UserDefaults` (defaults to `.standard`). The L1
    /// suite passes an isolated suite so the counter never leaks into the
    /// shared domain across tests.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The current consecutive-unhealthy-launch count. Zero on a fresh
    /// install or immediately after a healthy launch.
    public var unhealthyLaunchCount: Int {
        defaults.integer(forKey: Self.unhealthyLaunchCountKey)
    }

    /// `true` when the consecutive-unhealthy-launch count has reached
    /// ``unhealthyLaunchLimit`` — the signal for the host to force-disable the
    /// CloudKit opt-in flag and open a plain local container this launch
    /// (DUT-78). Read at container-build time, *after* ``recordLaunchStarted()``
    /// has already incremented the counter for the current attempt, so the
    /// crashing launch that pushes the count to the limit is itself the one
    /// that self-heals.
    public var shouldSelfHeal: Bool {
        unhealthyLaunchCount >= Self.unhealthyLaunchLimit
    }

    /// Record that a launch has begun but is not yet known-healthy (DUT-78).
    /// Called at the *very start* of launch (before any SwiftData / CloudKit
    /// container is built), so that a launch which then traps in CloudKit
    /// mirroring before reaching ``markLaunchHealthy()`` leaves the counter
    /// incremented. Returns the post-increment count so the caller can log it.
    @discardableResult
    public func recordLaunchStarted() -> Int {
        let next = unhealthyLaunchCount + 1
        defaults.set(next, forKey: Self.unhealthyLaunchCountKey)
        return next
    }

    /// Reset the consecutive-unhealthy-launch counter to zero (DUT-78).
    /// Called once the app has reached a known-good point this launch — the
    /// scene is on screen and the first run loop turned over, well past the
    /// window in which the async CloudKit mirroring trap fires. A launch that
    /// crashes before this is reached stays counted as unhealthy.
    public func markLaunchHealthy() {
        defaults.set(0, forKey: Self.unhealthyLaunchCountKey)
    }
}

import Testing

@testable import DODFeatureFeed

/// DUT-1181 — the notifications toggle's "off ⇒ silence" contract (DUT-379)
/// only ever flushed the guided-bake timer (`SystemBakeTimerNotifier`). The
/// Cook Mode per-step timer alert (`SystemCookStepTimerNotifier`, DODFeatureRecipeDetail,
/// DUT-604) shipped afterward and was never wired into the opt-out flush, so a
/// step timer scheduled while notifications were ON kept firing its system
/// banner after the user turned notifications OFF.
///
/// `DODFeatureFeed` must not depend on `DODFeatureRecipeDetail`, so the fix
/// (`SettingsViewModel+Notifications.swift`) duplicates
/// `SystemCookStepTimerNotifier`'s identifier scheme as a string literal —
/// this suite pins that duplication against the exact format documented on
/// `SystemCookStepTimerNotifier.identifier(recipeID:stepIndex:)`
/// (`"dod.cookMode.stepTimerDone.<recipeID>.<stepIndex>"`), mirroring how
/// `FirstCookoutBakeNotifierTests` pins `SystemBakeTimerNotifier.isBakeDoneIdentifier`.
///
/// Lives in its own file (not appended to `SettingsViewModelNotificationsTests`)
/// so that suite stays under the SwiftLint 400-line file_length cap.
@MainActor
@Suite("SettingsViewModel Cook Mode step-timer opt-out flush (DUT-1181)")
struct SettingsViewModelStepTimerFlushTests {

    // MARK: - Identifier scheme (pure — no UNUserNotificationCenter involved)

    @Test func baseIdentifierMatchesSystemCookStepTimerNotifierLiteral() {
        // Duplicated on purpose (cross-module boundary) — this pins the
        // duplication against the literal `SystemCookStepTimerNotifier.identifier`
        // carries in `CookStepTimerNotifier.swift` ("dod.cookMode.stepTimerDone").
        #expect(SettingsViewModel.cookModeStepTimerDoneBaseIdentifier == "dod.cookMode.stepTimerDone")
    }

    @Test func bareBaseIdentifierIsRecognized() {
        #expect(
            SettingsViewModel.isCookModeStepTimerDoneIdentifier(
                SettingsViewModel.cookModeStepTimerDoneBaseIdentifier
            )
        )
    }

    // DUT-604's per-(recipe, step) identifier is
    // "\(identifier).\(recipeID).\(stepIndex)" — verify distinct real-shaped
    // ids (mirroring `SystemCookStepTimerNotifier.identifier(recipeID:stepIndex:)`)
    // all match the flush's predicate.
    @Test func perRecipeStepIdentifiersAreRecognized() {
        let idA = "dod.cookMode.stepTimerDone.101.0"
        let idB = "dod.cookMode.stepTimerDone.202.3"
        #expect(SettingsViewModel.isCookModeStepTimerDoneIdentifier(idA))
        #expect(SettingsViewModel.isCookModeStepTimerDoneIdentifier(idB))
    }

    // The real regression this whole predicate exists to avoid: a request
    // belonging to a DIFFERENT notification family (e.g. the guided bake timer,
    // or some unrelated future local notification) must never be swept up by
    // this flush.
    @Test func unrelatedIdentifiersAreNotRecognized() {
        #expect(!SettingsViewModel.isCookModeStepTimerDoneIdentifier("dod.firstCookout.bakeDone"))
        #expect(!SettingsViewModel.isCookModeStepTimerDoneIdentifier("dod.firstCookout.bakeDone.101"))
        #expect(!SettingsViewModel.isCookModeStepTimerDoneIdentifier("dod.somethingElse"))
        // A prefix collision guard: a DIFFERENT base id that merely starts with
        // the same characters must not match (no accidental substring match).
        #expect(!SettingsViewModel.isCookModeStepTimerDoneIdentifier("dod.cookMode.stepTimerDoneExtra"))
    }

    // NOTE — no end-to-end `setNotificationsEnabled(false)` test here: the
    // macOS `swift test` slice has no host app bundle, and the PRE-EXISTING
    // `SystemBakeTimerNotifier().cancelAllBakeDone()` call this method already
    // made (before this fix) has no `hasHostBundle`-style guard, so it throws
    // `bundleProxyForCurrentProcess is nil` and aborts the test process the
    // moment anything calls this method under `swift test` — a latent,
    // pre-existing gap unrelated to this fix (this file's new
    // `cancelAllCookModeStepTimerNotifications()` IS guarded; it never even
    // gets reached because the older call aborts first). No test in this
    // package has ever exercised `setNotificationsEnabled(false)` for exactly
    // this reason. Fixing `SystemBakeTimerNotifier` is out of scope here — this
    // suite instead pins the identifier-matching logic above, which is the
    // actual new logic this fix introduces.
}

import DODDesignSystem
import DODFeatureFeed
import Foundation
import SwiftUI

extension RootView {

    /// DUT-335 — the App Intro cover content (extracted here so `RootView`'s
    /// body stays under the SwiftLint `file_length` cap). The persistent
    /// "Let's Get Cooking" CTA is the tour's single exit: it records onboarding
    /// as done and kicks off first-run setup (notifications + the deferred
    /// iCloud-Sync prompt).
    @MainActor
    var onboardingCover: some View {
        AppIntroWelcome(
            headline: "Welcome to Dutch Oven Daddy",
            intro: "Your guide from your first cookout to cast iron hero.",
            bullets: Self.appIntroBullets,
            ctaTitle: "Let's Get Cooking",
            onFinish: {
                guard showOnboarding else { return }  // DUT-407: ignore a double-tap
                UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
                // First-run prompts (skipped under the onboarding UI test, which
                // can't dismiss the system dialogs). Arm the pending flag BEFORE
                // dismissing so it's set no matter how fast the dismiss animation
                // (and its `onDismiss:`) races the async setup; the sync prompt
                // itself is presented from `presentCloudSyncPromptIfPending`.
                if !DODEnvironment.suppressFirstRunPrompts {
                    pendingCloudSyncPromptAfterOnboarding = true
                    Task { await runFirstRunSetup(presentingFromCoverDismiss: true) }
                }
                showOnboarding = false
            }
        )
    }

    /// DUT-408 / DUT-529 — the onboarding cover's `onDismiss:` completion. Fires
    /// after the dismiss animation finishes, so presenting the iCloud-Sync alert
    /// here can't be swallowed as present-during-dismiss (replaces the old fixed
    /// 450 ms sleep). No-op unless `onFinish` armed the pending flag.
    @MainActor
    func presentCloudSyncPromptIfPending() {
        guard pendingCloudSyncPromptAfterOnboarding else { return }
        pendingCloudSyncPromptAfterOnboarding = false
        showCloudSyncPrompt = true
    }

    /// The feature bullets of the single-screen first-launch **App Intro**
    /// (DUT-1089, CL-327 — replaces the DUT-335 paged `appIntroPages`). Declared
    /// static so the array isn't rebuilt every render and tests/previews reuse
    /// the exact content the app ships. Titles are Title Case; details are
    /// sentence case. The iCloud bullet carries the sync disclosure the welcome
    /// screen is now responsible for (CL-328 / DUT-1090).
    static var appIntroBullets: [AppIntroWelcome.Bullet] {
        [
            .init(
                id: 0,
                icon: "square.grid.2x2.fill",
                title: "Browse Recipes & Articles",
                detail: "Fresh cast iron recipes to cook and articles to read, all in one place."
            ),
            .init(
                id: 1,
                icon: "bookmark.fill",
                title: "Save Your Favorites",
                detail: "Bookmark any recipe to build your own collection and find it again in a tap."
            ),
            .init(
                id: 2,
                icon: "speaker.wave.2.fill",
                title: "Cook Mode",
                detail: "Cook one step at a time with large text, voice read-aloud, and a screen that stays awake."
            ),
            .init(
                id: 3,
                icon: "flame.fill",
                title: "Cooking Tools",
                detail: "Your First Cookout, the Heat Coach, and the shopping list, in the order you'll use them."
            ),
            .init(
                id: 4,
                icon: "arrow.down.circle.fill",
                title: "Cook Offline",
                detail: "Download recipes to your device and cook anywhere, even with no signal at the campsite."
            ),
            .init(
                id: 5,
                icon: "icloud.fill",
                title: "Synced Across Devices",
                detail: "Your saved recipes and cook journal stay with you on all your Apple "
                    + "devices. Turn it off any time in Settings."
            ),
        ]
    }

    /// First-run setup, run right after the welcome sheet's CTA on a brand-new
    /// install — and re-run next launch if a prior launch left it unfinished
    /// (DUT-280): ask for notification permission (the system prompt), then ask
    /// to turn on iCloud Sync. Both `Turn On iCloud Sync?` alert buttons set
    /// `firstRunPromptsCompletedKey`, so this never re-runs once answered.
    ///
    /// - Parameter presentingFromCoverDismiss: `true` when this runs off the
    ///   onboarding CTA (`onFinish`), while the `fullScreenCover` is still
    ///   dismissing. DUT-408: when notification auth is already decided,
    ///   `requestAuthorization` returns instantly (no system dialog), so setting
    ///   `showCloudSyncPrompt` here would present the alert mid-dismiss and iOS
    ///   swallows it (present-during-dismiss). In that case the caller (`onFinish`)
    ///   has already armed `pendingCloudSyncPromptAfterOnboarding`, and the cover's
    ///   `onDismiss:` presents the alert once the dismiss animation has finished
    ///   (see `RootView.swift`); this method leaves the prompt alone. When `false`
    ///   (the `.task` recovery path — no cover on screen) it presents directly.
    @MainActor
    func runFirstRunSetup(presentingFromCoverDismiss: Bool = false) async {
        // 1. Notifications — the system permission prompt. On grant, flip the app
        //    toggle so alerts fire without a second trip to Settings.
        let granted = await dependencies.notificationService.requestAuthorization()
        if granted {
            UserDefaults.standard.set(true, forKey: SettingsViewModel.notificationsEnabledKey)
            // DUT-1333 — allowing notifications opts you into new-article alerts
            // too ("When a New Article Drops"); it's off by default otherwise.
            UserDefaults.standard.set(
                true,
                forKey: SettingsViewModel.articleNotificationsEnabledKey
            )
        }
        // 2. iCloud Sync — ask (never silently enable). When riding the onboarding
        //    cover's dismissal the prompt is presented from `onDismiss:` (DUT-408),
        //    so do nothing here; otherwise present it now.
        if !presentingFromCoverDismiss {
            showCloudSyncPrompt = true
        }
    }

    /// DUT-400: migrate the pre-DUT-280 upgrade population — a user who onboarded
    /// before `firstRunPromptsCompletedKey` existed would otherwise get the recovery
    /// prompts fired unprompted on their first updated launch. Mark complete instead.
    /// A one-time, idempotent set; a fresh install (onboarding not done) is untouched.
    @MainActor
    func migrateFirstRunFlagsIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.onboardingCompletedKey),
            defaults.object(forKey: Self.firstRunPromptsCompletedKey) == nil
        else { return }
        defaults.set(true, forKey: Self.firstRunPromptsCompletedKey)
    }
}

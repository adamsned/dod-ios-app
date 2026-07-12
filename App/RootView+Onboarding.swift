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
        AppIntroTour(
            pages: Self.appIntroPages,
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

    /// The slides of the first-launch **App Intro** tour (DUT-335). Declared
    /// static so the array isn't rebuilt every render and tests/previews reuse
    /// the exact content the app ships. Spotlights only the standout, app-unique
    /// features — iCloud Sync is intentionally NOT a slide (it has its own
    /// first-run opt-in prompt, `runFirstRunSetup`). Titles are Title Case;
    /// descriptions are short but informative. `placeholderSymbol` stands in for
    /// the real app screenshot until those are wired up later.
    static var appIntroPages: [AppIntroTour.Page] {
        [
            .init(
                id: 0,
                title: "Welcome to Dutch Oven Daddy",
                description:
                    "Browse cast iron recipes and articles, save your favorites, and cook them step by step with built-in coaching, even offline.",
                placeholderSymbol: "flame.fill",
                // DUT-336: the opening slide leads with the Dutch Oven Daddy
                // badge (a bundled transparent PNG) as its clean welcome visual.
                // Later slides use SF-symbol placeholders until real screenshots
                // land. Media precedence is video → image → symbol.
                image: .logo
            ),
            .init(
                id: 1,
                title: "Browse Recipes & Articles",
                description: "Explore fresh cast iron recipes to cook and articles to read, all in one tab.",
                placeholderSymbol: "square.grid.2x2.fill"
            ),
            .init(
                id: 2,
                title: "Save Recipes for Later",
                description: "Bookmark any recipe to build your own collection and find it again in a tap.",
                placeholderSymbol: "bookmark.fill"
            ),
            .init(
                id: 3,
                title: "Cook Mode",
                description:
                    "Cook one step at a time with large text and voice read-aloud, and the screen stays awake so you never lose your place.",
                placeholderSymbol: "speaker.wave.2.fill"
            ),
            .init(
                id: 4,
                title: "Cooking Tools",
                description:
                    "New to cast iron? Your First Cookout walks you to a guaranteed win, and the Heat Coach dials in your coals so every cook comes out right.",
                placeholderSymbol: "thermometer.medium"
            ),
            .init(
                id: 5,
                title: "Download for Offline",
                description: "Save recipes to your device and cook anywhere, even with no signal at the campsite.",
                placeholderSymbol: "arrow.down.circle.fill"
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

import DODDesignSystem
import DODFeatureFeed
import Foundation
import SwiftUI

extension RootView {

    /// DUT-335 — the App Welcome cover content (extracted here so `RootView`'s
    /// body stays under the SwiftLint `file_length` cap). The persistent
    /// "Let's Get Cooking" CTA is the screen's single exit: it records onboarding
    /// as done and kicks off first-run setup (the notification permission prompt).
    @MainActor
    var onboardingCover: some View {
        AppWelcomeScreen(
            headline: "Welcome to Dutch Oven Daddy",
            intro: "New to cast iron? You're in the right place. Here's what's inside.",
            bullets: Self.appWelcomeBullets,
            disclosure: Self.appWelcomeDisclosure,
            ctaTitle: "Let's Get Cooking",
            onFinish: {
                guard showOnboarding else { return }  // DUT-407: ignore a double-tap
                UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
                // First-run prompts (skipped under the onboarding UI test, which
                // can't dismiss the system dialogs).
                if !DODEnvironment.suppressFirstRunPrompts {
                    Task { await runFirstRunSetup() }
                }
                showOnboarding = false
            }
        )
    }

    /// The standing iCloud disclosure on the welcome screen.
    ///
    /// Fresh installs default the sync opt-in ON (see
    /// `DODApp.resolveCloudKitSyncDefaultIfNeeded`), which retires the old
    /// first-run "Turn On iCloud Sync?" alert — so this line is the moment the
    /// user is told. It is pinned above the CTA rather than living in the bullet
    /// list on purpose: the bullets scroll, and a disclosure the user can tap
    /// past without reading isn't a disclosure.
    static let appWelcomeDisclosure =
        "Your saved recipes sync to iCloud automatically. Turn it off any time in Settings."

    /// The bullets of the first-launch **App Welcome** screen (DUT-335).
    /// Declared static so the array isn't rebuilt every render and
    /// tests/previews reuse the exact content the app ships. Titles are Title
    /// Case; descriptions are sentence case.
    ///
    /// iCloud Sync is deliberately NOT a bullet — it's the screen's standing
    /// `disclosure` line instead (see `appWelcomeDisclosure`).
    static var appWelcomeBullets: [AppWelcomeScreen.Bullet] {
        [
            .init(
                id: 0,
                title: "Browse Recipes & Articles",
                description: "Fresh cast iron recipes to cook and articles to read, all in one tab.",
                symbol: "square.grid.2x2.fill"
            ),
            .init(
                id: 1,
                title: "Save Your Favorites",
                description: "Tap the bookmark on any recipe to find it again later.",
                symbol: "bookmark.fill"
            ),
            .init(
                id: 2,
                title: "Cook Mode",
                description:
                    "Cook one step at a time with large text and voice read-aloud. The screen stays awake so you never lose your place.",
                symbol: "speaker.wave.2.fill"
            ),
            .init(
                id: 3,
                title: "Cooking Tools",
                description:
                    "Your First Cookout walks you to a guaranteed win, and the Heat Coach dials in your coals so every cook comes out right.",
                symbol: "thermometer.medium"
            ),
            .init(
                id: 4,
                title: "Download for Offline",
                description: "Save recipes to your device and cook anywhere, even with no signal at the campsite.",
                symbol: "arrow.down.circle.fill"
            ),
        ]
    }

    /// First-run setup, run right after the welcome screen's CTA on a brand-new
    /// install — and re-run next launch if a prior launch left it unfinished
    /// (DUT-280): ask for notification permission (the system prompt).
    ///
    /// The iCloud-Sync half is gone: sync is resolved once at launch (fresh
    /// installs default ON, everyone else is left exactly as they were — see
    /// `DODApp.resolveCloudKitSyncDefaultIfNeeded`) and disclosed by the welcome
    /// screen's standing disclosure line, so there is no longer an alert to ask.
    /// Settings remains the place to change it.
    ///
    /// Sets `firstRunPromptsCompletedKey` once the notification prompt is
    /// answered/dismissed, so it never re-runs — the DUT-280 contract, which the
    /// removed alert's buttons used to carry.
    @MainActor
    func runFirstRunSetup() async {
        // Notifications — the system permission prompt. On grant, flip the app
        // toggles so alerts fire without a second trip to Settings. Only on
        // grant: a denial must not leave the in-app switches reading "on".
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
        // DUT-280 — the first-run prompt is answered; mark complete so it never
        // re-runs. (Previously set by the iCloud alert's buttons, which were the
        // tail of this flow.)
        UserDefaults.standard.set(true, forKey: Self.firstRunPromptsCompletedKey)
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

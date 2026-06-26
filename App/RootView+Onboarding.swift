import DODDesignSystem
import DODFeatureFeed
import Foundation

extension RootView {

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
                placeholderSymbol: "flame.fill"
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
    @MainActor
    func runFirstRunSetup() async {
        // 1. Notifications — the system permission prompt. On grant, flip the app
        //    toggle so alerts fire without a second trip to Settings.
        let granted = await dependencies.notificationService.requestAuthorization()
        if granted {
            UserDefaults.standard.set(true, forKey: SettingsViewModel.notificationsEnabledKey)
        }
        // 2. iCloud Sync — ask (never silently enable). The alert presents next.
        showCloudSyncPrompt = true
    }
}

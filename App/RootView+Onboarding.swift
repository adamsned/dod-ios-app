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
            intro: Self.appWelcomeIntro,
            sectionTitle: Self.appWelcomeSectionTitle,
            bullets: Self.appWelcomeBullets(
                isSeasonedCastIronOn: appearance == .seasonedCastIron,
                trySeasonedCastIron: { trySeasonedCastIron() }
            ),
            disclosure: Self.appWelcomeDisclosure,
            ctaTitle: "Let's Get Cooking",
            onFinish: {
                guard showOnboarding else { return }  // DUT-407: ignore a double-tap
                UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
                // Recorded in the SAME synchronous beat as `onboardingCompletedKey`
                // (see that key's doc comment / `shouldMigrateFirstRunFlags`) so a
                // kill immediately after this tap is never confused for a
                // pre-DUT-280 legacy install by `migrateFirstRunFlagsIfNeeded`.
                UserDefaults.standard.set(true, forKey: Self.firstRunPromptsArmedKey)
                // First-run prompts (skipped under the onboarding UI test, which
                // can't dismiss the system dialogs).
                if !DODEnvironment.suppressFirstRunPrompts {
                    Task { await runFirstRunSetup() }
                }
                showOnboarding = false
                showFirstCookQuiz = true
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

    /// DUT-2896 (v2) — the intro is a one-sentence summary of what the app
    /// does (the old five-bullet tour: browse, save, Cook Mode, Cooking Tools,
    /// offline), freeing the bullet list for what's new in 2.0.
    static let appWelcomeIntro =
        "Browse cast iron recipes and articles, save your favorites, cook step by step in Cook Mode, "
        + "dial in your coals with the Heat Coach, and download recipes to cook offline."

    /// DUT-2896 — the heading over the bullets.
    static let appWelcomeSectionTitle = "New in 2.0"

    /// DUT-2896 — the "Try It" button's identifier (UI tests).
    static let appWelcomeTryThemeID = "app-intro-try-seasoned-cast-iron"

    /// The bullets of the first-launch **App Welcome** screen: DUT-335's tour,
    /// rewritten by DUT-2896 as the key features new in 2.0. Titles are Title
    /// Case; descriptions are sentence case (no em dashes in app copy).
    ///
    /// The Seasoned Cast Iron bullet carries a "Try It" button that switches the
    /// app to that theme on the spot; `isSeasonedCastIronOn` flips it to
    /// "Selected". iCloud Sync is deliberately NOT a bullet — it's the screen's
    /// standing `disclosure` line instead (see `appWelcomeDisclosure`).
    static func appWelcomeBullets(
        isSeasonedCastIronOn: Bool,
        trySeasonedCastIron: @MainActor @Sendable @escaping () -> Void
    ) -> [AppWelcomeScreen.Bullet] {
        [
            .init(
                id: 0,
                title: "Seasoned Cast Iron",
                description:
                    "A new true-black theme that's easy on the eyes by the campfire at night and gentle on your battery.",
                symbol: "moon.stars.fill",
                action: .init(
                    title: "Try It",
                    activeTitle: "Selected",
                    isActive: isSeasonedCastIronOn,
                    accessibilityIdentifier: appWelcomeTryThemeID,
                    perform: trySeasonedCastIron
                )
            ),
            .init(
                id: 1,
                title: "Hands-Free Voice",
                description:
                    "Ask Siri for the next step, to repeat one, or to scale the servings, and control your steps from your AirPods or Lock Screen.",
                symbol: "waveform"
            ),
            .init(
                id: 2,
                title: "Ask Dutch Oven Daddy",
                description:
                    "Get answers about cast iron, or ask any recipe about swaps, scaling, and timing. Powered by Apple Intelligence, right on your device.",
                symbol: "sparkles"
            ),
            .init(
                id: 3,
                title: "Siri & Shortcuts",
                description:
                    "Open a recipe, find something to cook, or add ingredients to your shopping list without opening the app.",
                symbol: "square.stack.3d.up.fill"
            ),
            .init(
                id: 4,
                title: "And More",
                description:
                    "A Ready to Serve check before you plate, Heat Coach weather from your location, a Shopping List widget, and polish throughout.",
                symbol: "ellipsis.circle.fill"
            ),
        ]
    }

    /// DUT-2896 — the welcome screen's "Try It": select the Seasoned Cast Iron
    /// appearance, exactly as picking it in Settings ▸ App Appearance does. The
    /// OLED flag flips BEFORE the preference so the re-render resolves the new
    /// surfaces (the same ordering `SettingsView.appearanceBinding` uses).
    @MainActor
    func trySeasonedCastIron() {
        DODColor.isOLEDDark = AppearancePreference.seasonedCastIron.isOLEDDark
        appearanceRaw = AppearancePreference.seasonedCastIron.rawValue
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
    ///
    /// Bug fixed here: `onboardingCompletedKey == true && firstRunPromptsCompletedKey
    /// == nil` is ALSO exactly the state of a brand-new, fully-current install that
    /// completed the onboarding CTA and then had the app killed before either
    /// first-run prompt resolved — the very case DUT-280's `firstRunPromptsCompletedKey`
    /// recovery (see `needsFirstRunPrompts` in `RootView.body`'s `.task`) exists to
    /// catch. Before this fix, this migration ran unconditionally on that state and
    /// stamped `firstRunPromptsCompletedKey = true` regardless, permanently defeating
    /// DUT-280's recovery: the notification-permission and iCloud-Sync prompts would
    /// never be asked again on that install. `firstRunPromptsArmedKey` disambiguates —
    /// it's set synchronously the instant onboarding completes under this
    /// (post-DUT-280) code, so its presence means "this is an interrupted CURRENT
    /// flow, not a legacy upgrade" and migration must be skipped.
    @MainActor
    func migrateFirstRunFlagsIfNeeded() {
        guard Self.shouldMigrateFirstRunFlags(in: .standard) else { return }
        UserDefaults.standard.set(true, forKey: Self.firstRunPromptsCompletedKey)
    }

    /// Pure decision logic for `migrateFirstRunFlagsIfNeeded` (DUT-400), extracted
    /// so it's unit-testable without a SwiftUI host — mirrors the
    /// `RootView.linkRoutingDestination(for:)` extraction pattern. `nonisolated`
    /// so it can be called from a test without hopping to `@MainActor`.
    nonisolated static func shouldMigrateFirstRunFlags(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: Self.onboardingCompletedKey)
            && defaults.object(forKey: Self.firstRunPromptsCompletedKey) == nil
            && defaults.object(forKey: Self.firstRunPromptsArmedKey) == nil
    }
}

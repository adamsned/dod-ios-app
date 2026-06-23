import DODDesignSystem

extension RootView {

    /// The highlight rows shown on the single first-launch welcome sheet.
    /// Declared as a static so the array is not rebuilt every render and so
    /// tests/previews can reuse the exact content the app ships. T-762 / CL-159
    /// (DUT-68) — reworded the Save row to the save-a-favorite-for-findability
    /// framing (T-761 decoupled Save from the offline download) and added the
    /// iCloud-Sync capability row (informational; the launch-time *ask* lives in
    /// `runFirstRunSetup`, the full toggle in Settings).
    static var welcomeBullets: [OnboardingSheet.Bullet] {
        [
            .init(
                systemImage: "house.fill",
                title: "Browse the latest",
                caption: "New cast iron recipes appear at the top."
            ),
            .init(
                systemImage: "magnifyingglass",
                title: "Search what you've got",
                caption: "Type any ingredient or technique to filter."
            ),
            .init(
                systemImage: "bookmark.fill",
                title: "Save your favorites",
                caption: "Tap the bookmark on any recipe to find it again later."
            ),
            .init(
                systemImage: "icloud.fill",
                title: "Sync across devices",
                caption: "Turn on iCloud Sync to keep your saved recipes on every device."
            ),
        ]
    }
}

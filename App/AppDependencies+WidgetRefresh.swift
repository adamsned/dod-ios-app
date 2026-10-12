import Foundation
import WidgetKit

// DUT-1380 — WidgetKit caches the rendered timeline-entry image, and the
// Featured/Latest widgets only reload on a ~4h fallback cadence. After an app
// update that changes widget layouts, the old render lingered on the home
// screen. Reload every widget timeline once per installed build.
extension AppDependencies {

    private static let widgetRefreshBuildKey = "widgetRefresh.lastBuild"

    /// Reloads all widget timelines the first time a given build launches.
    /// Idempotent within a build, so normal launches don't burn reload budget.
    func refreshWidgetsOnceForCurrentBuild(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        reload: () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard defaults.string(forKey: Self.widgetRefreshBuildKey) != build else { return }
        defaults.set(build, forKey: Self.widgetRefreshBuildKey)
        reload()
    }
}

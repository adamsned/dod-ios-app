import SwiftUI
import WidgetKit

/// Widget extension bundle for Dutch Oven Daddy Live Activities (US-11).
///
/// This extension exists solely to host the ``CookActivityWidget``
/// `ActivityConfiguration` so iOS can render the Lock Screen card and
/// Dynamic Island layouts when ``CookModeViewModel`` fires
/// `Activity<CookActivityAttributes>.request`. The host app embeds this
/// extension via `project.yml`.
///
/// Spec trace: US-11 (Live Activity for Cook Mode timers).
@main
struct DODAppLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        CookActivityWidget()
    }
}

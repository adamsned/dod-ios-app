import DODSupport
import UIKit

/// DUT-1397 — remote-push token callbacks.
extension AppDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        DODLog.app.info("push: APNs token received (\(PushTokenUploader.hex(deviceToken).count / 2) bytes)")
        let registrar = PushRuntime.registrar
        Task { @MainActor in
            await PushRuntime.uploader.didReceive(
                token: deviceToken,
                newRecipes: registrar.newRecipes,
                newArticles: registrar.newArticles
            )
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        DODLog.app.error("push: APNs registration failed: \(String(describing: error))")
    }

    /// Only runs for pushes that carry `content-available`; records the post so
    /// the background poller never announces it a second time.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let id = NotificationCoordinator.postID(fromUserInfo: userInfo) {
            NotifiedPostsStore().record(id)
        }
        completionHandler(.noData)
    }
}

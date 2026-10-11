import DODFeatureFeed
import DODSupport
import Foundation
import UIKit

/// DUT-1397 — decides whether this device should hold a remote-push
/// registration and keeps APNs + the backend in step with that decision.
///
/// Wanted = OS notification permission granted AND ("When New Recipes Drop" OR
/// "When a New Article Drops") is on. Wanted -> `registerForRemoteNotifications`
/// (the token arrives in `AppDelegate`, which hands it to the uploader).
/// Not wanted -> DELETE the token at the backend and unregister from APNs.
///
/// `reconcile(force: true)` runs on every launch / foreground (tokens can
/// change); `force: false` (UserDefaults changed, i.e. a toggle flip) is a
/// no-op unless the toggles actually moved.
@MainActor
final class RemotePushRegistrar {

    static let lastStateKey = "dod.push.lastReconciledState"

    enum Outcome: Equatable { case registered, unregistered, unchanged }

    private let defaults: UserDefaults
    private let isAuthorized: () async -> Bool
    private let registerWithAPNs: () -> Void
    private let unregisterFromAPNs: () -> Void
    private let uploader: PushTokenUploader

    init(
        defaults: UserDefaults = .standard,
        isAuthorized: @escaping () async -> Bool,
        registerWithAPNs: @escaping () -> Void,
        unregisterFromAPNs: @escaping () -> Void,
        uploader: PushTokenUploader
    ) {
        self.defaults = defaults
        self.isAuthorized = isAuthorized
        self.registerWithAPNs = registerWithAPNs
        self.unregisterFromAPNs = unregisterFromAPNs
        self.uploader = uploader
    }

    var newRecipes: Bool { defaults.bool(forKey: SettingsViewModel.notificationsEnabledKey) }
    var newArticles: Bool { defaults.bool(forKey: SettingsViewModel.articleNotificationsEnabledKey) }

    @discardableResult
    func reconcile(force: Bool) async -> Outcome {
        let toggles = "r\(newRecipes)a\(newArticles)"
        if !force, toggles == defaults.string(forKey: Self.lastStateKey) { return .unchanged }
        var wanted = newRecipes || newArticles
        if wanted { wanted = await isAuthorized() }
        defaults.set(toggles, forKey: Self.lastStateKey)
        if wanted {
            registerWithAPNs()
            // Token already known: push changed toggles / retry a failed upload now.
            await uploader.sync(newRecipes: newRecipes, newArticles: newArticles)
            return .registered
        }
        guard uploader.token != nil else { return .unchanged }
        await uploader.unregister()
        unregisterFromAPNs()
        return .unregistered
    }
}

/// App-lifetime wiring for the push pieces, used by `AppDelegate`.
@MainActor
enum PushRuntime {
    static let uploader = PushTokenUploader(
        client: AppDependencies.makeHTTPClient(), config: PushConfig.load())

    static let registrar = RemotePushRegistrar(
        isAuthorized: { await NotificationService().isAuthorized() },
        registerWithAPNs: { UIApplication.shared.registerForRemoteNotifications() },
        unregisterFromAPNs: { UIApplication.shared.unregisterForRemoteNotifications() },
        uploader: uploader)

    private static var observer: NSObjectProtocol?

    /// Launch / foreground entry point; also (once) watches for toggle flips.
    static func start() {
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main
            ) { _ in Task { @MainActor in await registrar.reconcile(force: false) } }
        }
        Task { await registrar.reconcile(force: true) }
    }
}

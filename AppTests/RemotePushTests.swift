import DODNetworking
import DODFeatureFeed
import Foundation
import Testing

@testable import DODApp

/// DUT-1397 — registrar decision table, token hex, uploader request shape +
/// retry flag, push userInfo routing, and the shared dedupe store.
@Suite("RemotePush", .serialized)
@MainActor
struct RemotePushTests {

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "RemotePushTests.\(UUID().uuidString)") ?? .standard
    }

    private let config = PushConfig(
        baseURL: URL(string: "https://push.example.com"),
        secret: "s3cret",
        environment: "development",
        bundleID: "com.dutchovendaddy.DODApp",
        appVersion: "1.2"
    )

    private func stubbed(status: Int) async -> FakeHTTPClient {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "push.example.com", json: Data("{}".utf8), statusCode: status)
        return fake
    }

    // MARK: hex

    @Test func tokenHex() {
        #expect(PushTokenUploader.hex(Data([0x00, 0xAB, 0x0F, 0xFF])) == "00ab0fff")
    }

    // MARK: uploader

    @Test func uploadRequestShape() async throws {
        let fake = await stubbed(status: 200)
        let suite = defaults()
        let up = PushTokenUploader(client: fake, config: config, defaults: suite)
        await up.didReceive(token: Data([1, 2]), newRecipes: true, newArticles: false)
        let req = try #require(await fake.capturedRequests.first)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.absoluteString == "https://push.example.com/register")
        #expect(req.value(forHTTPHeaderField: "X-App-Secret") == "s3cret")
        let body = try #require(req.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["token"] as? String == "0102")
        #expect(json["environment"] as? String == "development")
        #expect(json["bundleId"] as? String == "com.dutchovendaddy.DODApp")
        #expect(json["appVersion"] as? String == "1.2")
        #expect(json["newRecipes"] as? Bool == true)
        #expect(json["newArticles"] as? Bool == false)
        #expect(!up.needsUpload)
    }

    @Test func failedUploadKeepsNeedsUploadAndRetries() async {
        let suite = defaults()
        let failing = await stubbed(status: 500)
        let up = PushTokenUploader(client: failing, config: config, defaults: suite)
        await up.didReceive(token: Data([1]), newRecipes: true, newArticles: true)
        #expect(up.needsUpload)
        let ok = await stubbed(status: 200)
        let retry = PushTokenUploader(client: ok, config: config, defaults: suite)
        await retry.sync(newRecipes: true, newArticles: true)
        #expect(!retry.needsUpload)
        #expect(await ok.capturedRequests.count == 1)
        await retry.sync(newRecipes: true, newArticles: true)  // unchanged: no re-POST
        #expect(await ok.capturedRequests.count == 1)
        await retry.sync(newRecipes: true, newArticles: false)  // toggle changed: re-POST
        #expect(await ok.capturedRequests.count == 2)
    }

    @Test func unconfiguredIsNoOp() async {
        let fake = await stubbed(status: 200)
        var blank = config
        blank.baseURL = nil
        let up = PushTokenUploader(client: fake, config: blank, defaults: defaults())
        await up.didReceive(token: Data([1]), newRecipes: true, newArticles: true)
        #expect(await fake.capturedRequests.isEmpty)
    }

    @Test func unregisterSendsDeleteAndForgetsToken() async throws {
        let fake = await stubbed(status: 200)
        let up = PushTokenUploader(client: fake, config: config, defaults: defaults())
        await up.didReceive(token: Data([9]), newRecipes: true, newArticles: true)
        await up.unregister()
        let delete = try #require(await fake.capturedRequests.last)
        #expect(delete.httpMethod == "DELETE")
        #expect(up.token == nil)
    }

    @Test func environmentFromProvisioningProfile() {
        func profile(_ env: String) -> Data {
            Data("junk<key>aps-environment</key>\n\t<string>\(env)</string>junk".utf8)
        }
        #expect(PushConfig.apnsEnvironment(provisioningProfile: nil) == "production")
        #expect(PushConfig.apnsEnvironment(provisioningProfile: profile("development")) == "development")
        #expect(PushConfig.apnsEnvironment(provisioningProfile: profile("production")) == "production")
    }

    // MARK: registrar

    private func registrar(
        _ suite: UserDefaults,
        authorized: Bool,
        fake: FakeHTTPClient,
        hasToken: Bool = false
    ) -> (RemotePushRegistrar, Counter) {
        let counter = Counter()
        if hasToken { suite.set("abcd", forKey: PushTokenUploader.tokenKey) }
        let reg = RemotePushRegistrar(
            defaults: suite,
            isAuthorized: { authorized },
            registerWithAPNs: { counter.registers += 1 },
            unregisterFromAPNs: { counter.unregisters += 1 },
            uploader: PushTokenUploader(client: fake, config: config, defaults: suite)
        )
        return (reg, counter)
    }

    final class Counter { var registers = 0; var unregisters = 0 }

    @Test(arguments: [
        (true, false, true, true), (false, true, true, true), (true, true, true, true),
        (false, false, true, false), (true, true, false, false), (true, false, false, false),
    ])
    func registersOnlyWhenPermittedAndToggled(
        recipes: Bool,
        articles: Bool,
        authorized: Bool,
        expectRegister: Bool
    ) async {
        let suite = defaults()
        suite.set(recipes, forKey: SettingsViewModel.notificationsEnabledKey)
        suite.set(articles, forKey: SettingsViewModel.articleNotificationsEnabledKey)
        let (reg, count) = registrar(suite, authorized: authorized, fake: await stubbed(status: 200))
        let outcome = await reg.reconcile(force: true)
        #expect((count.registers == 1) == expectRegister)
        #expect(outcome == (expectRegister ? .registered : .unchanged))
    }

    @Test func turningTogglesOffUnregisters() async {
        let suite = defaults()
        let fake = await stubbed(status: 200)
        let (reg, count) = registrar(suite, authorized: true, fake: fake, hasToken: true)
        suite.set(true, forKey: SettingsViewModel.notificationsEnabledKey)
        #expect(await reg.reconcile(force: true) == .registered)
        suite.set(false, forKey: SettingsViewModel.notificationsEnabledKey)
        #expect(await reg.reconcile(force: false) == .unregistered)
        #expect(count.unregisters == 1)
        #expect(await fake.capturedRequests.last?.httpMethod == "DELETE")
    }

    @Test func revokedPermissionUnregisters() async {
        let suite = defaults()
        suite.set(true, forKey: SettingsViewModel.notificationsEnabledKey)
        let (reg, count) = registrar(suite, authorized: false, fake: await stubbed(status: 200), hasToken: true)
        #expect(await reg.reconcile(force: true) == .unregistered)
        #expect(count.unregisters == 1)
    }

    @Test func unforcedReconcileWithSameTogglesIsNoOp() async {
        let suite = defaults()
        suite.set(true, forKey: SettingsViewModel.notificationsEnabledKey)
        let (reg, count) = registrar(suite, authorized: true, fake: await stubbed(status: 200))
        await reg.reconcile(force: true)
        #expect(await reg.reconcile(force: false) == .unchanged)
        #expect(count.registers == 1)
    }

    // MARK: routing

    @Test func pushUserInfoRoutes() {
        let info: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "t", "body": "b"], "sound": "default"],
            "postId": 4321,
            "postKind": "article",
        ]
        #expect(NotificationCoordinator.intent(fromUserInfo: info) == .openRecipe(id: 4321))
        let recipeInfo: [AnyHashable: Any] = ["postId": 77, "postKind": "recipe"]
        #expect(NotificationCoordinator.intent(fromUserInfo: recipeInfo) == .openRecipe(id: 77))
        #expect(NotificationCoordinator.intent(fromUserInfo: ["postId": "88"]) == .openRecipe(id: 88))
        #expect(NotificationCoordinator.intent(fromUserInfo: ["aps": [:]]) == nil)
        #expect(NotificationCoordinator.intent(fromUserInfo: ["postId": -1]) == nil)
    }

    @Test func localNotificationUserInfoStillRoutes() {
        #expect(
            NotificationCoordinator.intent(fromUserInfo: ["dod.deeplink": "dod://recipe/5"]) == .openRecipe(id: 5))
    }

    // MARK: dedupe

    @Test func dedupeStore() {
        let store = NotifiedPostsStore(defaults: defaults())
        store.record(1)
        store.record(2)
        #expect(store.contains(1))
        #expect(store.unannounced([1, 2, 3, 4], alreadyDelivered: [4]) == [3])
        for id in 100..<(100 + NotifiedPostsStore.capacity + 5) { store.record(id) }
        #expect(store.ids.count == NotifiedPostsStore.capacity)
        #expect(!store.contains(1))
    }
}

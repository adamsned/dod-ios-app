import DODNetworking
import DODSupport
import Foundation

/// DUT-1397 — configuration for the push backend. Both values come from
/// Info.plist (`DODPushBaseURL`, `DODPushSharedSecret`), which project.yml fills
/// from the `DOD_PUSH_BASE_URL` / `DOD_PUSH_APP_SECRET` build settings: blank in
/// the committed `App/DODApp.xcconfig` (no secret in this public repo), injected
/// at archive time (release.yml) or via the gitignored `DODApp.local.xcconfig`.
/// Blank (or still a `REPLACE_ME` placeholder) means "not configured" and the
/// uploader is a logged no-op.
struct PushConfig: Equatable {
    var baseURL: URL?
    var secret: String
    var environment: String
    var bundleID: String
    var appVersion: String

    var isConfigured: Bool { baseURL != nil && !secret.isEmpty }

    static func load(bundle: Bundle = .main) -> PushConfig {
        func plist(_ key: String) -> String {
            let raw = (bundle.object(forInfoDictionaryKey: key) as? String) ?? ""
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.contains("REPLACE_ME") ? "" : trimmed
        }
        let base = plist("DODPushBaseURL")
        let profile = bundle.path(forResource: "embedded", ofType: "mobileprovision")
            .flatMap { FileManager.default.contents(atPath: $0) }
        return PushConfig(
            baseURL: base.isEmpty ? nil : URL(string: base),
            secret: plist("DODPushSharedSecret"),
            environment: apnsEnvironment(provisioningProfile: profile),
            bundleID: bundle.bundleIdentifier ?? "com.dutchovendaddy.DODApp",
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        )
    }

    /// APNs environment the device token belongs to. Development-signed builds
    /// (Xcode / debug) embed a provisioning profile whose entitlements carry
    /// `aps-environment = development`; App Store and TestFlight builds are
    /// re-signed without an embedded profile and always use production APNs. So:
    /// profile present and says development -> "development", else "production".
    static func apnsEnvironment(provisioningProfile: Data?) -> String {
        guard let profile = provisioningProfile else { return "production" }
        // The profile is a CMS blob wrapping an XML plist; the plist text is
        // readable as Latin-1 without verifying the signature.
        let text = String(data: profile, encoding: .isoLatin1) ?? ""
        let pattern = #"aps-environment</key>\s*<string>(development|production)</string>"#
        guard
            let range = text.range(of: pattern, options: .regularExpression),
            text[range].contains("development")
        else { return "production" }
        return "development"
    }
}

/// DUT-1397 — registers / unregisters this device's APNs token with the push
/// backend. Backend contract (all requests carry `X-App-Secret`):
/// - `POST   <base>/register` JSON `{token, environment, bundleId, appVersion, newRecipes, newArticles}`
/// - `DELETE <base>/register` JSON `{token}`
/// Upload state lives in `UserDefaults` so a failed upload is retried on the
/// next launch / foreground (`needsUpload`).
@MainActor
final class PushTokenUploader {

    static let tokenKey = "dod.push.deviceToken"
    static let needsUploadKey = "dod.push.needsUpload"
    static let lastUploadedKey = "dod.push.lastUploadedFingerprint"

    private let client: HTTPClient
    private let defaults: UserDefaults
    private let config: PushConfig

    init(client: HTTPClient, config: PushConfig, defaults: UserDefaults = .standard) {
        self.client = client
        self.config = config
        self.defaults = defaults
    }

    var token: String? { defaults.string(forKey: Self.tokenKey) }
    var needsUpload: Bool { defaults.bool(forKey: Self.needsUploadKey) }

    /// Lowercase hex of the raw APNs token bytes.
    nonisolated static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }

    /// APNs handed us a (possibly new) token.
    func didReceive(token data: Data, newRecipes: Bool, newArticles: Bool) async {
        defaults.set(Self.hex(data), forKey: Self.tokenKey)
        await sync(newRecipes: newRecipes, newArticles: newArticles)
    }

    /// Uploads if the token / preferences / version differ from the last
    /// successful upload, or a previous attempt failed. No-op without a token.
    func sync(newRecipes: Bool, newArticles: Bool) async {
        guard let token else { return }
        let parts = [token, config.environment, config.appVersion, "\(newRecipes)", "\(newArticles)"]
        let fingerprint = parts.joined(separator: "|")
        if fingerprint != defaults.string(forKey: Self.lastUploadedKey) {
            defaults.set(true, forKey: Self.needsUploadKey)
        }
        guard needsUpload else { return }
        guard let url = registerURL() else { return }
        let body = Register(
            token: token,
            environment: config.environment,
            bundleId: config.bundleID,
            appVersion: config.appVersion,
            newRecipes: newRecipes,
            newArticles: newArticles
        )
        if await send(method: "POST", url: url, body: body) {
            defaults.set(fingerprint, forKey: Self.lastUploadedKey)
            defaults.set(false, forKey: Self.needsUploadKey)
        }
    }

    /// Tells the backend to stop pushing to this device. The local token is
    /// forgotten only on success, so a failure is retried on the next reconcile.
    func unregister() async {
        guard let token, let url = registerURL() else { return }
        if await send(method: "DELETE", url: url, body: Unregister(token: token)) {
            defaults.removeObject(forKey: Self.tokenKey)
            defaults.removeObject(forKey: Self.lastUploadedKey)
            defaults.set(false, forKey: Self.needsUploadKey)
        }
    }

    // MARK: - Private

    private struct Register: Encodable {
        let token, environment, bundleId, appVersion: String
        let newRecipes, newArticles: Bool
    }

    private struct Unregister: Encodable { let token: String }

    private func registerURL() -> URL? {
        guard config.isConfigured, let base = config.baseURL else {
            DODLog.app.info("push: PUSH_BASE_URL / shared secret not configured; skipping")
            return nil
        }
        return base.appendingPathComponent("register")
    }

    private func send(method: String, url: URL, body: some Encodable) async -> Bool {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.secret, forHTTPHeaderField: "X-App-Secret")
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (_, response) = try await client.data(for: request)
            guard (200..<300).contains(response.statusCode) else {
                DODLog.app.error("push: \(method) /register returned \(response.statusCode)")
                return false
            }
            return true
        } catch {
            DODLog.app.error("push: \(method) /register failed: \(String(describing: error))")
            return false
        }
    }
}

import Foundation

/// DUT-176 — the category a user picks in the Send Feedback sheet.
public enum FeedbackCategory: String, CaseIterable, Sendable, Identifiable {
    case bug, idea, other
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .bug: "Bug"
        case .idea: "Idea"
        case .other: "Other"
        }
    }
}

/// Anonymous device context. Only attached when the user opts in.
public struct FeedbackDiagnostics: Sendable, Equatable {
    public var appVersion: String
    public var osVersion: String
    public var deviceModel: String
    public var currentScreen: String
    public init(appVersion: String, osVersion: String, deviceModel: String, currentScreen: String) {
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.currentScreen = currentScreen
    }
}

public struct FeedbackReport: Sendable, Equatable {
    public static let recipient = "ned@dutchovendaddy.com"
    public var category: FeedbackCategory
    public var text: String
    public var diagnostics: FeedbackDiagnostics?  // nil unless the user opted in
    public init(category: FeedbackCategory, text: String, diagnostics: FeedbackDiagnostics? = nil) {
        self.category = category
        self.text = text
        self.diagnostics = diagnostics
    }

    /// Submission requires non-empty text after trimming whitespace.
    public var isSubmittable: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var subject: String { "[DOD Feedback] \(category.title)" }

    public var body: String {
        var out = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let diagnosticsInfo = diagnostics {
            out +=
                "\n\n--- Diagnostics ---\nApp version: \(diagnosticsInfo.appVersion)\nOS version: \(diagnosticsInfo.osVersion)\nDevice: \(diagnosticsInfo.deviceModel)\nScreen: \(diagnosticsInfo.currentScreen)"
        }
        return out
    }

    /// Pre-filled mailto: URL, or nil if the text is empty.
    public var mailtoURL: URL? {
        guard isSubmittable else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

extension FeedbackDiagnostics {
    /// Local, anonymous context. `screen` is a stable screen id such as "feed" or "saved".
    public static func current(
        screen: String,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> FeedbackDiagnostics {
        let info = bundle.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        let os = processInfo.operatingSystemVersion
        return FeedbackDiagnostics(
            appVersion: "\(version) (\(build))",
            osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            deviceModel: machineIdentifier(),
            currentScreen: screen
        )
    }

    private static func machineIdentifier() -> String {
        var sys = utsname()
        uname(&sys)
        let mirror = Mirror(reflecting: sys.machine)
        let id = mirror.children.reduce("") { acc, element in
            guard let value = element.value as? Int8, value != 0 else { return acc }
            return acc + String(UnicodeScalar(UInt8(value)))
        }
        return id.isEmpty ? "unknown" : id
    }
}

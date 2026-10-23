import SwiftUI

/// Why a load failed. Drives friendly, actionable copy (DUT-134).
public enum LoadFailureKind: Sendable, Equatable {
    case noConnection
    case requestFailed

    public var systemImage: String {
        switch self {
        case .noConnection: "wifi.slash"
        case .requestFailed: "exclamationmark.arrow.triangle.2.circlepath"
        }
    }
    public var title: String {
        switch self {
        case .noConnection: "You're offline"
        case .requestFailed: "Something went wrong"
        }
    }
    public var message: String {
        switch self {
        case .noConnection: "Check your connection and try again. Saved recipes still work offline."
        case .requestFailed: "We couldn't finish that request. Please try again."
        }
    }
}

/// Single shared inline error + Retry surface. Wraps `EmptyState`.
public struct RetryStateView: View {
    public let kind: LoadFailureKind
    public let retry: @MainActor () -> Void
    public init(kind: LoadFailureKind, retry: @MainActor @escaping () -> Void) {
        self.kind = kind
        self.retry = retry
    }
    public var body: some View {
        EmptyState(
            systemImage: kind.systemImage,
            title: kind.title,
            message: kind.message,
            action: .init(title: "Retry", handler: retry)
        )
    }
}

#Preview("No connection") { RetryStateView(kind: .noConnection) {} }
#Preview("Request failed") { RetryStateView(kind: .requestFailed) {} }

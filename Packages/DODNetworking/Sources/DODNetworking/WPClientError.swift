import Foundation

/// Typed networking errors. View models translate these into the
/// human-readable empty/error states required by spec CC-4.
public enum WPClientError: Error, Sendable, Equatable {
    /// Device has no connectivity (offline).
    case networkUnavailable
    /// Request timed out.
    case timeout
    /// Non-success HTTP status code.
    case httpStatus(Int)
    /// Response body could not be decoded.
    case decoding(message: String)
    /// Anything else from the URL loading system.
    case underlying(message: String)

    /// Coalesce an arbitrary thrown error into a typed case.
    public static func wrap(_ error: Error) -> WPClientError {
        if let wpError = error as? WPClientError {
            return wpError
        }
        let urlError = error as? URLError
        switch urlError?.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .networkUnavailable
        case .timedOut:
            return .timeout
        case .some:
            return .underlying(message: urlError?.localizedDescription ?? "URL error")
        case .none:
            return .underlying(message: error.localizedDescription)
        }
    }
}

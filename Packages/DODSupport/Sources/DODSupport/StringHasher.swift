import CryptoKit
import Foundation

/// Stable SHA256 hex digest, used to anonymize search queries before sending
/// to TelemetryDeck (constitution §9, spec AC-3.6). Input is trimmed and
/// lowercased so that semantically-equal queries hash identically.
public enum StringHasher {

    /// 64-char lowercase hex digest of SHA256(lowercased-trimmed-input).
    public static func sha256Hex(_ input: String) -> String {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

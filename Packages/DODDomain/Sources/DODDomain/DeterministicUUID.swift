import Foundation

/// DUT-641: derive a STABLE `UUID` from a string, so value types whose identity
/// is content-based (e.g. ``RecipeIngredient``) get the same `id` every time the
/// same text is parsed. Fixes check-state (keyed on `id`) clearing when a recipe
/// re-parses mid-session.
///
/// Not cryptographic — it's a name-based UUID built from a stable FNV-1a hash of
/// the UTF-8 bytes, expanded to 16 bytes and stamped with the RFC 4122 version
/// (5) + variant bits so the value is a well-formed UUID. Determinism is the
/// only contract; collision resistance beyond "distinct lines get distinct ids
/// in practice" is not required.
public enum DeterministicUUID {

    /// Stable UUID for `text`. `from(x) == from(x)` for all `x`; distinct inputs
    /// yield distinct outputs in practice.
    public static func from(_ text: String) -> UUID {
        // Two independent FNV-1a passes (base offset + a salted offset) give 16
        // deterministic bytes without pulling in a crypto dependency.
        let low = fnv1a(text.utf8, seed: 0xcbf2_9ce4_8422_2325)
        let high = fnv1a(text.utf8, seed: 0x84222325_cbf29ce4 &+ 0x9e37_79b9_7f4a_7c15)
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8((low >> (UInt64(index) * 8)) & 0xff)
            bytes[8 + index] = UInt8((high >> (UInt64(index) * 8)) & 0xff)
        }
        // RFC 4122: set version (5 — name-based) and variant (10xx) bits.
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }

    private static func fnv1a(_ bytes: String.UTF8View, seed: UInt64) -> UInt64 {
        var hash = seed
        let prime: UInt64 = 0x0000_0100_0000_01b3
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }
}

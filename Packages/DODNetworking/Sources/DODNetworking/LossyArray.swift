import Foundation

/// A `Decodable` array wrapper that decodes elements **lossily**: an element
/// that fails to decode is skipped rather than failing the whole collection.
///
/// DUT-575: WP list endpoints (`/posts`) return one atomic JSON array, so a
/// single malformed row (e.g. a draft-state post whose required field can't be
/// decoded) otherwise throws `.decoding` for the ENTIRE page → the feed /
/// category / search screen renders empty instead of "all rows minus the bad
/// one." Wrapping the array decode in `LossyArray` makes the page resilient:
/// the good rows survive, the bad row is dropped. This mirrors the per-field
/// leniency the `WPDTO.Comment` DTO already carries (DUT-27/384) but applies it
/// at the collection level so even a row that fails for a *different* reason
/// (missing `id`, a wholly mis-shaped object) can't nuke the page.
struct LossyArray<Element: Decodable>: Decodable {

    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Element] = []
        if let count = container.count {
            decoded.reserveCapacity(count)
        }
        while !container.isAtEnd {
            // `LossyElement.init` never throws — it captures a per-element decode
            // failure as `nil` while ALWAYS consuming exactly one entry, so the
            // unkeyed container's cursor advances by one on every iteration
            // (a bare `try?` on the element type would not consume a failed
            // entry and would spin forever; consuming a second value in a
            // fallback path would skip the innocent NEXT row). A failed element
            // is dropped; a good one is kept.
            let holder = try container.decode(LossyElement<Element>.self)
            if let value = holder.value {
                decoded.append(value)
            }
        }
        self.elements = decoded
    }
}

/// Decodes a single element, capturing a decode failure as `nil` while still
/// consuming exactly one entry from the surrounding unkeyed container.
private struct LossyElement<Element: Decodable>: Decodable {

    let value: Element?

    init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        self.value = try? single.decode(Element.self)
    }
}

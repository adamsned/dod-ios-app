import Foundation

public struct BringListStore: Sendable {
    private let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() -> BringList {
        guard let data = try? Data(contentsOf: fileURL),
            let list = try? JSONDecoder().decode(BringList.self, from: data)
        else { return BringList() }
        return list
    }

    public func save(_ list: BringList) throws {
        let data = try JSONEncoder().encode(list)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Re-seed while preserving packed state: any item in `fresh` whose id was packed in `existing` stays packed.
    public static func merge(existing: BringList, fresh: BringList) -> BringList {
        let packed = Set(existing.items.filter(\.isPacked).map(\.id))
        var out = fresh
        for index in out.items.indices where packed.contains(out.items[index].id) { out.items[index].isPacked = true }
        return out
    }
}

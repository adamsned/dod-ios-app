import Foundation
import Testing

@testable import DODPersistence

/// L1 coverage for the file-backed cook-journal photo store (US-48 / DUT-104).
/// Uses a unique temp directory per test so nothing touches real app storage.
@Suite("CookPhotoStore (DUT-104)") struct CookPhotoStoreTests {

    private func tempStore() -> CookPhotoStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CookPhotoStoreTests-\(UUID().uuidString)", isDirectory: true)
        return CookPhotoStore(directory: dir)
    }

    @Test func savesAndReadsBackTheBytes() throws {
        let store = tempStore()
        let bytes = Data([0x01, 0x02, 0x03, 0x04])
        let id = try store.save(bytes)
        #expect(id.hasSuffix(".jpg"))
        #expect(store.data(forID: id) == bytes)
    }

    @Test func missingIDReturnsNil() {
        let store = tempStore()
        #expect(store.data(forID: "does-not-exist.jpg") == nil)
    }

    @Test func deleteRemovesTheFile() throws {
        let store = tempStore()
        let id = try store.save(Data([0xAA]))
        #expect(store.data(forID: id) != nil)
        store.delete(id: id)
        #expect(store.data(forID: id) == nil)
    }
}

import Foundation
import Testing

@testable import DODPersistence

/// L1 coverage for the file-backed per-recipe annotation store (iPad + Apple
/// Pencil, v2). Uses a unique temp directory per test so nothing touches real
/// app storage. The store round-trips opaque `Data` (a stand-in for
/// `PKDrawing.dataRepresentation()`), so these run on the macOS `swift test`
/// slice with no PencilKit dependency.
@Suite("RecipeAnnotationStore") struct RecipeAnnotationStoreTests {

    private func tempStore() -> FileRecipeAnnotationStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecipeAnnotationStoreTests-\(UUID().uuidString)", isDirectory: true)
        return FileRecipeAnnotationStore(directory: dir)
    }

    @Test func savesAndReadsBackARecord() throws {
        let store = tempStore()
        let record = RecipeAnnotationRecord(drawingData: Data([0x01, 0x02, 0x03]), canvasWidth: 640)
        try store.save(record, forRecipeID: 42)
        #expect(store.annotation(forRecipeID: 42) == record)
    }

    @Test func missingRecipeIDReturnsNil() {
        let store = tempStore()
        #expect(store.annotation(forRecipeID: 999) == nil)
    }

    @Test func recordsAreKeyedPerRecipe() throws {
        let store = tempStore()
        let first = RecipeAnnotationRecord(drawingData: Data([0xAA]), canvasWidth: 320)
        let second = RecipeAnnotationRecord(drawingData: Data([0xBB]), canvasWidth: 500)
        try store.save(first, forRecipeID: 1)
        try store.save(second, forRecipeID: 2)
        #expect(store.annotation(forRecipeID: 1) == first)
        #expect(store.annotation(forRecipeID: 2) == second)
    }

    @Test func savingOverwritesTheExistingRecord() throws {
        let store = tempStore()
        try store.save(RecipeAnnotationRecord(drawingData: Data([0x01]), canvasWidth: 300), forRecipeID: 7)
        let updated = RecipeAnnotationRecord(drawingData: Data([0x09, 0x09]), canvasWidth: 720)
        try store.save(updated, forRecipeID: 7)
        #expect(store.annotation(forRecipeID: 7) == updated)
    }

    @Test func deleteRemovesTheRecord() throws {
        let store = tempStore()
        try store.save(RecipeAnnotationRecord(drawingData: Data([0x05]), canvasWidth: 400), forRecipeID: 3)
        #expect(store.annotation(forRecipeID: 3) != nil)
        store.delete(forRecipeID: 3)
        #expect(store.annotation(forRecipeID: 3) == nil)
    }

    @Test func persistsAcrossStoreInstancesAtTheSameDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecipeAnnotationStoreTests-\(UUID().uuidString)", isDirectory: true)
        let record = RecipeAnnotationRecord(drawingData: Data([0x11, 0x22]), canvasWidth: 512)
        try FileRecipeAnnotationStore(directory: dir).save(record, forRecipeID: 88)
        // A fresh instance rooted at the same directory reads the persisted record.
        #expect(FileRecipeAnnotationStore(directory: dir).annotation(forRecipeID: 88) == record)
    }

    @Test func canvasWidthRoundTrips() throws {
        let store = tempStore()
        try store.save(RecipeAnnotationRecord(drawingData: Data(), canvasWidth: 834.5), forRecipeID: 4)
        #expect(store.annotation(forRecipeID: 4)?.canvasWidth == 834.5)
    }

    @Test func inMemoryFakeRoundTrips() throws {
        let store = InMemoryRecipeAnnotationStore()
        let record = RecipeAnnotationRecord(drawingData: Data([0xCA, 0xFE]), canvasWidth: 600)
        #expect(store.annotation(forRecipeID: 5) == nil)
        try store.save(record, forRecipeID: 5)
        #expect(store.annotation(forRecipeID: 5) == record)
        store.delete(forRecipeID: 5)
        #expect(store.annotation(forRecipeID: 5) == nil)
    }
}

import XCTest

@testable import DODSupport

final class ProbeTargetStoreTests: XCTestCase {
    func testInitialValue() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)
        let store = ProbeTargetStore(defaults: defaults ?? .standard)
        XCTAssertNil(store.target(forRecipe: 1))
    }

    func testSetValue() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)
        let store = ProbeTargetStore(defaults: defaults ?? .standard)

        store.setTarget(165, forRecipe: 1)
        XCTAssertEqual(store.target(forRecipe: 1), 165)
    }

    func testDifferentRecipeId() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)
        let store = ProbeTargetStore(defaults: defaults ?? .standard)

        store.setTarget(165, forRecipe: 1)
        XCTAssertNil(store.target(forRecipe: 2))
    }
}

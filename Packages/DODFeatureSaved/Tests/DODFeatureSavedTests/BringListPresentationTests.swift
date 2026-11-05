import DODSupport
import Testing

@testable import DODFeatureSaved

@Suite struct BringListPresentationTests {
    @Test func displayNameForFuel() {
        #expect(BringListPresentation.displayName(.fuel) == "Coals & Fuel")
    }

    @Test func displayNameIsNonEmptyForAllCategories() {
        for category in BringListCategory.allCases {
            #expect(!BringListPresentation.displayName(category).isEmpty)
        }
    }

    @Test func everyCategoryHasAGlyph() {
        for category in BringListCategory.allCases {
            #expect(!BringListPresentation.glyph(category).isEmpty)
        }
    }
}

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

    @Test func rowLabelShowsQuantityWhenAboveOne() {
        let item = BringListItem(
            id: "charcoal briquettes",
            name: "Charcoal briquettes",
            category: .fuel,
            quantity: 3
        )
        #expect(BringListPresentation.rowLabel(item) == "3 x Charcoal briquettes")
    }

    @Test func rowLabelIsJustNameForSingleItem() {
        let item = BringListItem(id: "tongs", name: "Tongs", category: .tools)
        #expect(BringListPresentation.rowLabel(item) == "Tongs")
    }
}

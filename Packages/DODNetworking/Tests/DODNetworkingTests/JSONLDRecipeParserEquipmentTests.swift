import DODDomain
import Foundation
import Testing

@testable import DODNetworking

@Suite("JSONLDRecipeParser.mapEquipment (DUT-984)") struct MapEquipmentTests {

    @Test func mapEquipmentReadsCardNames() {
        let html = """
            <div class=\"wprm-recipe-container\"><ul><li class=\"wprm-recipe-equipment-item\"><div class=\"wprm-recipe-equipment-name\">Lid Lifter</div></li></ul></div>
            """
        #expect(JSONLDRecipeParser.mapEquipment(html: html).map(\.name) == ["Lid Lifter"])
        #expect(JSONLDRecipeParser.mapEquipment(html: "<p>none</p>").isEmpty)
    }
}

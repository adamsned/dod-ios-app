import Foundation
import Testing

@testable import DODDomain

@Suite("BrowseAxis (DUT-2137)")
struct BrowseAxisTests {
    @Test func decodesAxesAndValues() throws {
        let json = """
            {"axes":[{"slug":"course","title":"Course","values":[\
            {"slug":"dinner","title":"Dinner","tagIDs":[12]}]}]}
            """
        let config = try BrowseAxesConfig.decode(from: Data(json.utf8))
        #expect(config.axes.count == 1)
        #expect(config.axes.first?.slug == "course")
        #expect(config.axes.first?.title == "Course")
        #expect(config.axes.first?.values.first?.slug == "dinner")
        #expect(config.axes.first?.values.first?.title == "Dinner")
        #expect(config.axes.first?.values.first?.tagIDs == [12])
    }

    @Test func dropsValuesWithoutTagsAndEmptyAxes() throws {
        let json = """
            {"axes":[\
            {"slug":"course","title":"Course","values":[\
            {"slug":"dinner","title":"Dinner","tagIDs":[12]},\
            {"slug":"lunch","title":"Lunch","tagIDs":[]}]},\
            {"slug":"size","title":"Size","values":[\
            {"slug":"5qt","title":"5 qt","tagIDs":[]}]}]}
            """
        let config = try BrowseAxesConfig.decode(from: Data(json.utf8))
        #expect(config.axes.map(\.slug) == ["course"])
        #expect(config.axes.first?.values.map(\.slug) == ["dinner"])
    }
}

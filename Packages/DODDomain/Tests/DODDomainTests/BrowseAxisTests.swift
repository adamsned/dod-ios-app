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
}

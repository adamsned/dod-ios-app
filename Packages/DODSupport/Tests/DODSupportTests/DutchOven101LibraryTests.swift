import Foundation
import Testing

@testable import DODSupport

/// L1 unit coverage for ``DutchOven101Library`` — the pure, bundled-in-code
/// beginner technique-guide library behind the "Learn" surface (US-52 /
/// AC-52.1, CL-203, T-809).
///
/// These tests pin the structural contract every guide must honor so a future
/// content edit that drops a section, empties a takeaway, or collides a slug
/// trips CI rather than shipping a malformed lesson to a beginner. The "Learn"
/// library UI and per-guide read-state persistence are later slices and are
/// out of scope here — this suite exercises the content core only.
@Suite("DutchOven101Library") struct DutchOven101LibraryTests {

    @Test func libraryShipsAtLeastSixGuides() {
        #expect(DutchOven101Library.guides.count >= 6)
    }

    @Test func everyGuideIsWellFormed() {
        for guide in DutchOven101Library.guides {
            #expect(!guide.slug.isEmpty)
            #expect(!guide.title.isEmpty)
            #expect(guide.estimatedReadMinutes > 0)

            // Two to four ordered sections, each with non-empty heading + body.
            #expect(guide.sections.count >= 2)
            for section in guide.sections {
                #expect(!section.heading.isEmpty)
                #expect(!section.body.isEmpty)
            }

            // Two to four one-line key takeaways, each non-empty.
            #expect(guide.keyTakeaways.count >= 2)
            for takeaway in guide.keyTakeaways {
                #expect(!takeaway.isEmpty)
            }
        }
    }

    @Test func allSlugsAreUnique() {
        let slugs = DutchOven101Library.guides.map(\.slug)
        #expect(Set(slugs).count == slugs.count)
    }

    @Test func guideLookupReturnsTheMatchingGuide() {
        for guide in DutchOven101Library.guides {
            let found = DutchOven101Library.guide(slug: guide.slug)
            #expect(found == guide)
            #expect(found?.id == guide.slug)
        }
    }

    @Test func guideLookupReturnsNilForUnknownSlug() {
        #expect(DutchOven101Library.guide(slug: "no-such-guide") == nil)
        #expect(DutchOven101Library.guide(slug: "") == nil)
    }
}

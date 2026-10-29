import Foundation
import Testing

@testable import DODNetworking

@Suite("WPDTO.MediaDetails tolerant decoding") struct WPDTOMediaDetailsDecodeTests {

    private func decodeDetails(_ json: String) throws -> WPDTO.MediaDetails {
        try JSONDecoder().decode(WPDTO.MediaDetails.self, from: Data(json.utf8))
    }

    private func decodeMedia(_ json: String) throws -> WPDTO.Media {
        try JSONDecoder().decode(WPDTO.Media.self, from: Data(json.utf8))
    }

    @Test func validSizesObjectDecodesItsEntries() throws {
        let json = #"""
            {"sizes":{
              "large":{"source_url":"https://example.com/large.jpg","width":1024,"height":768},
              "thumbnail":{"source_url":"https://example.com/thumb.jpg","width":150,"height":150}
            }}
            """#
        let details = try decodeDetails(json)
        let sizes = try #require(details.sizes)
        #expect(sizes.count == 2)
        #expect(sizes["large"]?.sourceURL?.absoluteString == "https://example.com/large.jpg")
        #expect(sizes["large"]?.width == 1024)
        #expect(sizes["thumbnail"]?.height == 150)
    }

    @Test func missingSizesKeyGivesNil() throws {
        let details = try decodeDetails("{}")
        #expect(details.sizes == nil)
    }

    @Test func emptySizesObjectGivesAnEmptyDictionary() throws {
        let details = try decodeDetails(#"{"sizes":{}}"#)
        #expect(details.sizes?.isEmpty == true)
    }

    @Test func sizesAsStringGivesNilWithoutThrowing() throws {
        let details = try decodeDetails(#"{"sizes":"oops"}"#)
        #expect(details.sizes == nil)
    }

    @Test func sizesAsNonEmptyArrayGivesNilWithoutThrowing() throws {
        let details = try decodeDetails(#"{"sizes":[1,2,3]}"#)
        #expect(details.sizes == nil)
    }

    @Test func sizesAsNumberGivesNil() throws {
        let details = try decodeDetails(#"{"sizes":7}"#)
        #expect(details.sizes == nil)
    }

    @Test func sizesNullGivesNil() throws {
        let details = try decodeDetails(#"{"sizes":null}"#)
        #expect(details.sizes == nil)
    }

    @Test func oneWrongTypedEntryNilsTheWholeSizesDictionary() throws {
        let json = #"{"sizes":{"large":{"source_url":"https://example.com/l.jpg","width":"wide"}}}"#
        let details = try decodeDetails(json)
        #expect(details.sizes == nil)
    }

    @Test func mediaDetailsFalseDoesNotThrowAndHasNoSizes() throws {
        let media = try decodeMedia(#"{"source_url":"https://example.com/a.jpg","media_details":false}"#)
        #expect(media.sourceURL?.absoluteString == "https://example.com/a.jpg")
        #expect(media.mediaDetails?.sizes == nil)
    }

    @Test func mediaDetailsStringDoesNotThrowAndHasNoSizes() throws {
        let media = try decodeMedia(#"{"source_url":"https://example.com/a.jpg","media_details":"none"}"#)
        #expect(media.mediaDetails?.sizes == nil)
    }

    @Test func mediaDetailsMissingLeavesMediaDetailsNil() throws {
        let media = try decodeMedia(#"{"source_url":"https://example.com/a.jpg"}"#)
        #expect(media.mediaDetails == nil)
    }

    @Test func mediaDetailsWithValidSizesDecodesThroughMedia() throws {
        let json = #"""
            {"source_url":"https://example.com/a.jpg",
              "media_details":{"sizes":{"large":{"source_url":"https://example.com/l.jpg","width":10,"height":20}}}}
            """#
        let media = try decodeMedia(json)
        #expect(media.mediaDetails?.sizes?["large"]?.width == 10)
    }
}

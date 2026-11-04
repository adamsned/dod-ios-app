import Testing
import XCTest

@testable import DODIntelligence

@Suite struct CommentDigestPipelineTests {
    @Test func chunkRespectsCharacterCap() async {
        let bodies = Array(repeating: String(repeating: "a", count: 1000), count: 10)
        let chunks = CommentDigestPipeline.chunk(bodies)
        #expect(chunks.count >= 2)
        for chunk in chunks {
            let totalChars = chunk.reduce(0) { $0 + $1.count }
            #expect(totalChars <= CommentDigestPipeline.maxChunkCharacters)
        }
    }

    @Test func selectKeepsLongestWhenOverCap() {
        let bodies = Array(repeating: String(repeating: "a", count: 100), count: 80)
        let selected = CommentDigestPipeline.select(bodies)
        #expect(selected.count == CommentDigestPipeline.maxComments)
    }

    @Test func selectDropsShortBodies() {
        let bodies = ["short", "a bit longer body", String(repeating: "a", count: 25)]
        let selected = CommentDigestPipeline.select(bodies)
        #expect(selected.count == 1)
        #expect(selected[0] == String(repeating: "a", count: 25))
    }

    @Test func runReducesMultiplePartials() async {
        var callCount = 0
        let bodies = Array(repeating: String(repeating: "a", count: 1000), count: 20)

        let result = await CommentDigestPipeline.run(bodies: bodies) { _ in
            callCount += 1
            return CommentDigest(
                summary: "Summary \(callCount)",
                tips: ["Tip \(callCount)"],
                gotchas: ["Gotcha \(callCount)"]
            )
        }

        #expect(callCount == 2)  // 1 for first chunk, 1 for reduced result
        #expect(result != nil)
    }

    @Test func runDropsUngroundedTips() async {
        let bodies = ["body1", "body2"]

        let result = await CommentDigestPipeline.run(bodies: bodies) { _ in
            CommentDigest(
                summary: "Summary",
                tips: ["Tip not in bodies"],  // This should be dropped
                gotchas: ["Gotcha"]
            )
        }

        #expect(result == nil)
    }

    @Test func runReturnsNilForEmptyInput() async {
        let result = await CommentDigestPipeline.run(bodies: []) { _ in
            CommentDigest(
                summary: "Summary",
                tips: ["Tip"],
                gotchas: ["Gotcha"]
            )
        }

        #expect(result == nil)
    }
}

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
        let counter = CallCounter()
        // 12 grounded ~1,000-char bodies pack into 2 chunks of 6.
        let bodies = Array(repeating: String(repeating: "summary gotcha ", count: 66), count: 12)

        let result = await CommentDigestPipeline.run(bodies: bodies) { _ in
            let callCount = await counter.increment()
            return CommentDigest(
                summary: "Summary \(callCount)",
                tips: ["Tip \(callCount)"],
                gotchas: ["Gotcha \(callCount)"]
            )
        }

        #expect(await counter.count == 3)  // 2 chunks + 1 reduce
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

private actor CallCounter {
    private(set) var count = 0
    func increment() -> Int {
        count += 1
        return count
    }
}

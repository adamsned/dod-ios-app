import Foundation
import Testing

@testable import DODSupport

@MainActor
private final class OpenRecorder {
    var urls: [URL] = []
}

@MainActor
@Suite("RecipeLinkOpener") struct RecipeLinkOpenerTests {

    @Test func openPassesTheExactURLToTheHandler() async throws {
        let recorder = OpenRecorder()
        let opener = RecipeLinkOpener(open: { url in
            recorder.urls.append(url)
            return true
        })
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/some-recipe/?a=1#frag"))
        _ = await opener.open(url)
        #expect(recorder.urls == [url])
    }

    @Test func openReturnsTrueWhenTheHandlerReturnsTrue() async throws {
        let opener = RecipeLinkOpener(open: { _ in true })
        let url = try #require(URL(string: "https://example.com/a"))
        #expect(await opener.open(url) == true)
    }

    @Test func openReturnsFalseWhenTheHandlerReturnsFalse() async throws {
        let opener = RecipeLinkOpener(open: { _ in false })
        let url = try #require(URL(string: "https://example.com/a"))
        #expect(await opener.open(url) == false)
    }

    @Test func handlerRunsOncePerOpen() async throws {
        let recorder = OpenRecorder()
        let opener = RecipeLinkOpener(open: { url in
            recorder.urls.append(url)
            return true
        })
        let url = try #require(URL(string: "https://example.com/a"))
        _ = await opener.open(url)
        #expect(recorder.urls.count == 1)
        _ = await opener.open(url)
        #expect(recorder.urls.count == 2)
    }

    @Test func openingTwoDifferentURLsPassesEachInOrder() async throws {
        let recorder = OpenRecorder()
        let opener = RecipeLinkOpener(open: { url in
            recorder.urls.append(url)
            return false
        })
        let first = try #require(URL(string: "https://example.com/one"))
        let second = try #require(URL(string: "https://example.com/two"))
        _ = await opener.open(first)
        _ = await opener.open(second)
        #expect(recorder.urls == [first, second])
    }

    @Test func eachOpenReturnsTheHandlersLatestAnswer() async throws {
        let recorder = OpenRecorder()
        let opener = RecipeLinkOpener(open: { url in
            recorder.urls.append(url)
            return recorder.urls.count == 1  // true on the first call, false after
        })
        let url = try #require(URL(string: "https://example.com/a"))
        #expect(await opener.open(url) == true)
        #expect(await opener.open(url) == false)
    }

    @Test func handlerThatSuspendsStillReturnsItsResult() async throws {
        let opener = RecipeLinkOpener(open: { _ in
            await Task.yield()
            return true
        })
        let url = try #require(URL(string: "https://example.com/a"))
        #expect(await opener.open(url) == true)
    }
}

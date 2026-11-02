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
}

import DODDomain
import DODPersistence
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite
struct SnapshotBridgingTests {

    // MARK: - Fixtures

    private func url(_ string: String) -> URL {
        // Safe URL creation for test fixtures. All test URLs in this suite are hardcoded and valid.
        guard let url = URL(string: string) else {
            fatalError("Invalid test URL: \(string)")
        }
        return url
    }

    private func makeSnapshot(
        id: Int = 123,
        postID: Int = 999,
        parentID: Int? = nil,
        authorName: String = "Test Author",
        avatarURLString: String? = nil,
        dateGMT: Date = Date(timeIntervalSince1970: 1_609_459_200),  // 2021-01-01 00:00:00 UTC
        bodyText: String = "Great recipe!",
        ratingValue: Int? = nil,
        statusRaw: String = "approved"
    ) -> CachedCommentSnapshot {
        CachedCommentSnapshot(
            id: id,
            postID: postID,
            parentID: parentID,
            authorName: authorName,
            avatarURLString: avatarURLString,
            dateGMT: dateGMT,
            bodyText: bodyText,
            ratingValue: ratingValue,
            statusRaw: statusRaw
        )
    }

    private func makeComment(
        id: Int = 123,
        postID: Int = 999,
        parentID: Int? = nil,
        authorName: String = "Test Author",
        avatarURL: URL? = nil,
        dateGMT: Date = Date(timeIntervalSince1970: 1_609_459_200),
        body: String = "Great recipe!",
        ratingValue: Int? = nil,
        status: RecipeComment.Status = .approved
    ) -> RecipeComment {
        RecipeComment(
            id: id,
            postID: postID,
            parentID: parentID,
            authorName: authorName,
            avatarURL: avatarURL,
            dateGMT: dateGMT,
            body: body,
            ratingValue: ratingValue,
            status: status
        )
    }

    // MARK: - snapshotToComment Tests

    @Test("snapshotToComment with valid avatarURLString parses to URL correctly")
    func validAvatarURLStringParses() {
        let urlString = "https://example.com/avatars/user123.jpg"
        let comment = LiveRecipeDetailDependencies.snapshotToComment(makeSnapshot(avatarURLString: urlString))
        #expect(comment.avatarURL != nil)
        #expect(comment.avatarURL?.absoluteString == urlString)
    }

    @Test("snapshotToComment with nil avatarURLString produces nil avatarURL")
    func nilAvatarURLStringProducesNilURL() {
        let comment = LiveRecipeDetailDependencies.snapshotToComment(makeSnapshot(avatarURLString: nil))
        #expect(comment.avatarURL == nil)
    }

    @Test("snapshotToComment with empty string avatarURLString produces nil avatarURL")
    func emptyAvatarURLStringProducesNilURL() {
        let comment = LiveRecipeDetailDependencies.snapshotToComment(makeSnapshot(avatarURLString: ""))
        #expect(comment.avatarURL == nil)
    }

    @Test("snapshotToComment with whitespace-only avatarURLString produces URL with encoded spaces")
    func whitespaceOnlyAvatarURLStringProducesEncodedURL() {
        let comment = LiveRecipeDetailDependencies.snapshotToComment(makeSnapshot(avatarURLString: "   "))
        // Swift's URL(string:) is permissive: "   " → URL with %20%20%20 (valid per RFC, not usable).
        #expect(comment.avatarURL?.absoluteString == "%20%20%20")
    }

    @Test("snapshotToComment with recognized statusRaw maps to correct Status case")
    func recognizedStatusMapsCorrectly() {
        let testCases: [(String, RecipeComment.Status)] = [
            ("approved", .approved), ("hold", .hold), ("spam", .spam),
            ("trash", .trash), ("unknown", .unknown),
        ]
        for (rawValue, expectedStatus) in testCases {
            let snapshot = makeSnapshot(statusRaw: rawValue)
            let comment = LiveRecipeDetailDependencies.snapshotToComment(snapshot)
            #expect(comment.status == expectedStatus, "statusRaw '\(rawValue)' should map to \(expectedStatus)")
        }
    }

    @Test("snapshotToComment with unrecognized statusRaw falls back to unknown")
    func unrecognizedStatusFallsBackToUnknown() {
        let unrecognizedStatuses = ["deleted_by_admin", "archived", "future_status", "invalid"]

        for statusRaw in unrecognizedStatuses {
            let snapshot = makeSnapshot(statusRaw: statusRaw)
            let comment = LiveRecipeDetailDependencies.snapshotToComment(snapshot)
            #expect(comment.status == .unknown, "Unrecognized statusRaw '\(statusRaw)' should fall back to .unknown")
        }
    }

    @Test("snapshotToComment preserves core fields")
    func coreFieldsPreserved() {
        let id = 456
        let postID = 789
        let parentID: Int? = 123
        let authorName = "Alice"
        let dateGMT = Date(timeIntervalSince1970: 1_609_459_200)
        let bodyText = "Wonderful dish!"
        let ratingValue = 4

        let snapshot = makeSnapshot(
            id: id,
            postID: postID,
            parentID: parentID,
            authorName: authorName,
            dateGMT: dateGMT,
            bodyText: bodyText,
            ratingValue: ratingValue,
            statusRaw: "approved"
        )

        let comment = LiveRecipeDetailDependencies.snapshotToComment(snapshot)

        #expect(comment.id == id)
        #expect(comment.postID == postID)
        #expect(comment.parentID == parentID)
        #expect(comment.authorName == authorName)
        #expect(comment.dateGMT == dateGMT)
        #expect(comment.body == bodyText)
        #expect(comment.ratingValue == ratingValue)
        #expect(comment.status == .approved)
    }

    @Test("snapshotToComment with nil ratingValue")
    func nilRatingValuePreserved() {
        let snapshot = makeSnapshot(ratingValue: nil)
        let comment = LiveRecipeDetailDependencies.snapshotToComment(snapshot)
        #expect(comment.ratingValue == nil)
    }

    @Test("snapshotToComment with nil parentID")
    func nilParentIDPreserved() {
        let snapshot = makeSnapshot(parentID: nil)
        let comment = LiveRecipeDetailDependencies.snapshotToComment(snapshot)
        #expect(comment.parentID == nil)
    }

    // MARK: - commentToSnapshot Tests

    @Test("commentToSnapshot uses postID parameter, not from comment")
    func snapshotUsesPostIDParameter() {
        let commentPostID = 111
        let parameterPostID = 222

        let comment = makeComment(postID: commentPostID)
        let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(comment, postID: parameterPostID)

        // The snapshot should use the parameter postID, not the comment's postID
        #expect(snapshot.postID == parameterPostID)
        #expect(snapshot.postID != commentPostID)
    }

    @Test("commentToSnapshot isPendingFromThisDevice is always false")
    func isPendingFromThisDeviceAlwaysFalse() {
        // isPendingFromThisDevice is intentionally always false. Wave-1 design: true only for
        // newly-posted comments not yet synced. cachePendingComment(...) sets it true explicitly.
        let comment = makeComment()
        let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(comment, postID: 999)
        #expect(snapshot.isPendingFromThisDevice == false)
    }

    @Test("commentToSnapshot with nil avatarURL produces nil avatarURLString")
    func nilAvatarURLProducesNilString() {
        let comment = makeComment(avatarURL: nil)
        let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(comment, postID: 999)

        #expect(snapshot.avatarURLString == nil)
    }

    @Test("commentToSnapshot with valid avatarURL produces correct absoluteString")
    func validAvatarURLProducesString() {
        let urlString = "https://gravatar.com/avatar/abc123"
        let comment = makeComment(avatarURL: url(urlString))
        let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(comment, postID: 999)
        #expect(snapshot.avatarURLString == urlString)
    }

    @Test("commentToSnapshot maps all comment fields correctly")
    func allCommentFieldsMappedCorrectly() {
        let comment = makeComment(
            id: 789,
            postID: 555,
            parentID: 456,
            authorName: "Bob",
            avatarURL: url("https://example.com/bob.jpg"),
            dateGMT: Date(timeIntervalSince1970: 1_609_459_200),
            body: "Delicious!",
            ratingValue: 5,
            status: .hold
        )
        let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(comment, postID: 888)
        #expect(snapshot.id == 789)
        #expect(snapshot.postID == 888)
        #expect(snapshot.parentID == 456)
        #expect(snapshot.authorName == "Bob")
        #expect(snapshot.dateGMT == Date(timeIntervalSince1970: 1_609_459_200))
        #expect(snapshot.bodyText == "Delicious!")
        #expect(snapshot.ratingValue == 5)
        #expect(snapshot.statusRaw == "hold")
        #expect(snapshot.avatarURLString == "https://example.com/bob.jpg")
    }

    @Test("commentToSnapshot maps status.rawValue correctly for all Status cases")
    func statusRawValueMappedCorrectly() {
        let testCases: [(RecipeComment.Status, String)] = [
            (.approved, "approved"),
            (.hold, "hold"),
            (.spam, "spam"),
            (.trash, "trash"),
            (.unknown, "unknown"),
        ]

        for (status, expectedRaw) in testCases {
            let comment = makeComment(status: status)
            let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(comment, postID: 999)
            #expect(snapshot.statusRaw == expectedRaw, "Status \(status) should map to rawValue '\(expectedRaw)'")
        }
    }

    @Test("commentToSnapshot with nil ratingValue")
    func nilRatingValueInCommentProducesNilSnapshot() {
        let comment = makeComment(ratingValue: nil)
        let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(comment, postID: 999)

        #expect(snapshot.ratingValue == nil)
    }

    @Test("commentToSnapshot with nil parentID")
    func nilParentIDInCommentProducesNilSnapshot() {
        let comment = makeComment(parentID: nil)
        let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(comment, postID: 999)

        #expect(snapshot.parentID == nil)
    }

    // MARK: - Round-trip Tests

    @Test("Round-trip preserves key fields: id, parentID, authorName, body, ratingValue, status")
    func roundTripPreservesKeyFields() {
        let originalComment = makeComment(
            id: 321,
            postID: 111,
            parentID: 222,
            authorName: "Charlie",
            dateGMT: Date(timeIntervalSince1970: 1_609_459_200),
            body: "So tasty!",
            ratingValue: 3,
            status: .spam
        )

        let roundTripPostID = 555
        let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(originalComment, postID: roundTripPostID)
        let reconstructedComment = LiveRecipeDetailDependencies.snapshotToComment(snapshot)

        // Fields that should survive the round-trip:
        #expect(reconstructedComment.id == originalComment.id)
        #expect(reconstructedComment.parentID == originalComment.parentID)
        #expect(reconstructedComment.authorName == originalComment.authorName)
        #expect(reconstructedComment.body == originalComment.body)
        #expect(reconstructedComment.ratingValue == originalComment.ratingValue)
        #expect(reconstructedComment.status == originalComment.status)

        // dateGMT should also survive (it's in CachedCommentSnapshot)
        #expect(reconstructedComment.dateGMT == originalComment.dateGMT)

        // Note: postID in reconstructedComment will be roundTripPostID (from the snapshot),
        // not originalComment.postID, because commentToSnapshot's parameter overrides it.
        // authorEmail is not in CachedCommentSnapshot, so it reverts to default "".
    }

    @Test("Round-trip with avatarURL preserves URL through snapshot")
    func roundTripPreservesAvatarURL() {
        let avatarURL = url("https://example.com/user.jpg")
        let originalComment = makeComment(avatarURL: avatarURL)
        let snapshot = LiveRecipeDetailDependencies.commentToSnapshot(originalComment, postID: 999)
        let reconstructedComment = LiveRecipeDetailDependencies.snapshotToComment(snapshot)
        #expect(reconstructedComment.avatarURL == avatarURL)
    }
}

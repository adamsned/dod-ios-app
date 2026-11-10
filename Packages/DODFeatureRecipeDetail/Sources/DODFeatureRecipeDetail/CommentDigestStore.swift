import DODDomain
import DODIntelligence
import Foundation
import Observation

/// DUT-1914 — observable state holder for the Community Wisdom digest card.
/// A separate class (not a view-model extension) because `@Observable` stored state
/// must live in the class body and `RecipeDetailViewModel.swift` is near its SwiftLint cap.
@MainActor
@Observable
public final class CommentDigestStore {
    public enum State: Equatable, Sendable {
        case idle
        case loading
        case loaded(CommentDigest)
        case unavailable
    }

    /// Regenerate only when at least this many NEW approved comments arrived.
    public static let regenerationThreshold = 5
    /// Need at least this many approved comments to be worth a digest.
    public static let minimumComments = 3

    public private(set) var state: State = .idle
    private let intelligence: (any DODIntelligenceService)?
    private var digestedCount = 0

    public init(intelligence: (any DODIntelligenceService)?) {
        self.intelligence = intelligence
    }

    /// STRICTLY `.approved`, newest first, bodies only.
    nonisolated static func approvedBodies(_ comments: [RecipeComment]) -> [String] {
        comments.filter { $0.status == .approved }
            .sorted { $0.dateGMT > $1.dateGMT }
            .map(\.body)
    }

    public func refresh(comments: [RecipeComment]) async {
        guard let intelligence, intelligence.isAvailable else {
            state = .unavailable
            return
        }
        let bodies = Self.approvedBodies(comments)
        guard bodies.count >= Self.minimumComments else {
            state = .unavailable
            return
        }
        state = .loading
        if let digest = await intelligence.summarizeComments(bodies) {
            digestedCount = bodies.count
            state = .loaded(digest)
        } else {
            state = .unavailable
        }
    }
}

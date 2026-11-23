import DODIntelligence
import DODSupport
import Foundation
import Observation

/// DUT-1032 — drives the short conversational welcome (3 questions).
@MainActor @Observable
final class OnboardingIntakeModel {

    static let questions = [
        "What scares you most about cooking with cast iron?",
        "What occasion are you building toward — a Tuesday dinner, or a campout?",
        "How many people are you usually feeding?",
    ]

    private(set) var answers: [IntakeAnswer] = []
    private(set) var isFinished = false
    private(set) var profile: CookIntakeProfile?

    private let service: any DODIntelligenceService
    private let store: CookIntakeProfileStore

    init(service: any DODIntelligenceService, store: CookIntakeProfileStore = CookIntakeProfileStore()) {
        self.service = service
        self.store = store
    }

    /// The question to show now, or nil once all are answered.
    var currentQuestion: String? {
        answers.count < Self.questions.count ? Self.questions[answers.count] : nil
    }

    /// Records an answer; blank answers are ignored. After the last one, extracts + saves.
    func submit(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let question = currentQuestion, !trimmed.isEmpty, !isFinished else { return }
        answers.append(IntakeAnswer(question: question, answer: trimmed))
        guard currentQuestion == nil else { return }
        if let result = await service.extractIntakeProfile(from: answers) {
            store.save(result)
            profile = result
        } else {
            store.markSkipped()
        }
        isFinished = true
    }

    /// Ends the intake early: nothing is saved and the intake is never re-offered.
    func skipIntake() {
        guard !isFinished else { return }
        store.markSkipped()
        isFinished = true
    }
}

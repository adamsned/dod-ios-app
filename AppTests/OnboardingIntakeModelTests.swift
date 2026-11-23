import DODIntelligence
import DODSupport
import Foundation
import Testing

@testable import DODApp

/// DUT-1032 — the 3-question onboarding intake state machine.
@MainActor
@Suite struct OnboardingIntakeModelTests {

    private static func makeStore() -> CookIntakeProfileStore {
        CookIntakeProfileStore(defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard)
    }

    private static func answerAll(_ model: OnboardingIntakeModel) async {
        await model.submit("Rust")
        await model.submit("A campout")
        await model.submit("Four")
    }

    @Test func asksThreeQuestionsThenSavesProfile() async {
        let store = Self.makeStore()
        let model = OnboardingIntakeModel(service: FakeIntelligenceService(), store: store)
        await Self.answerAll(model)
        #expect(model.isFinished)
        #expect(store.profile()?.householdSize == 4)
        #expect(model.currentQuestion == nil)
    }

    @Test func blankAnswerIsIgnored() async {
        let model = OnboardingIntakeModel(service: FakeIntelligenceService(), store: Self.makeStore())
        await model.submit("  ")
        #expect(model.answers.isEmpty)
        #expect(model.currentQuestion == OnboardingIntakeModel.questions[0])
    }

    @Test func unavailableModelMarksSkippedWithoutProfile() async {
        let store = Self.makeStore()
        let model = OnboardingIntakeModel(service: FakeIntelligenceService(isAvailable: false), store: store)
        await Self.answerAll(model)
        #expect(model.isFinished)
        #expect(model.profile == nil)
        #expect(store.isCompleted)
    }

    @Test func skipCompletesImmediately() {
        let store = Self.makeStore()
        let model = OnboardingIntakeModel(service: FakeIntelligenceService(), store: store)
        model.skipIntake()
        #expect(model.isFinished)
        #expect(store.isCompleted)
        #expect(store.profile() == nil)
    }
}

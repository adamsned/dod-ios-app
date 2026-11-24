import Testing

@testable import DODSupport

@Suite struct StepTimerExtractorTests {
    private struct StubLLM: StepTimerLLMExtracting {
        let result: StepTimerExtraction?
        func extract(from text: String) async -> StepTimerExtraction? { result }
    }

    @Test func heuristicWinsLLMNotUsed() async {
        let extractor = StepTimerExtractor()
        let result = await extractor.extract(from: "Bake 30 minutes")
        #expect(result.timers.count == 1)
        #expect(result.timers[0].seconds == 1800)  // 30 minutes
    }

    @Test func llmFillsGapWhenTimeWordPresent() async {
        let extractor = StepTimerExtractor(
            llm: StubLLM(
                result: StepTimerExtraction(timers: [StepTimer(label: "Rest", seconds: 7200)], temperatureF: nil)
            )
        )
        let result = await extractor.extract(from: "Rest until the dough doubles, a couple of hours")
        #expect(result.timers.count == 1)
        #expect(result.timers[0].seconds == 7200)
    }

    @Test func llmRejectedWithoutTimeWord() async {
        let extractor = StepTimerExtractor(
            llm: StubLLM(
                result: StepTimerExtraction(timers: [StepTimer(label: "Stir", seconds: 300)], temperatureF: nil)
            )
        )
        let result = await extractor.extract(from: "Stir gently")
        #expect(result.timers.isEmpty)
    }

    @Test func llmOutOfRangeRejected() async {
        let extractor = StepTimerExtractor(
            llm: StubLLM(
                result: StepTimerExtraction(timers: [StepTimer(label: "Test", seconds: 999_999)], temperatureF: nil)
            )
        )
        let result = await extractor.extract(from: "Rest for a while")
        #expect(result.timers.isEmpty)
    }

    @Test func noLLMReturnsHeuristic() async {
        let extractor = StepTimerExtractor()
        let result = await extractor.extract(from: "Bake 10 minutes")
        #expect(result.timers.count == 1)
        #expect(result.timers[0].seconds == 600)  // 10 minutes
    }
}

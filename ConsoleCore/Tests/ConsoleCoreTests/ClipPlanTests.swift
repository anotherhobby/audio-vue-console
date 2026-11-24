import Testing

@testable import ConsoleCore

/// `track-render`, "A clip runs at 30 or 60 frames a second".
struct ClipPlanTests {
    @Test func thirtyFramesASecondAt48kHz() {
        let plan = ClipPlan(rate: 48_000, fps: 30, start: 10, end: 30)
        #expect(Array(plan.moments.prefix(3)) == [480_000, 481_600, 483_200])
    }

    @Test func twentySecondsAtSixtyIsTwelveHundredFrames() {
        #expect(ClipPlan(rate: 44_100, fps: 60, start: 60, end: 80).count == 1_200)
    }

    @Test func aSpanEndingBetweenFramesKeepsTheFrameStartedBeforeIt() {
        #expect(ClipPlan(rate: 48_000, fps: 30, start: 0, end: 0.05).count == 2)
    }

    @Test func theMomentsOnlyRise() {
        let moments = ClipPlan(rate: 44_100, fps: 30, start: 1.234, end: 4).moments
        #expect(zip(moments, moments.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func anEmptySpanHasNoFrames() {
        #expect(ClipPlan(rate: 48_000, fps: 30, start: 5, end: 5).moments.isEmpty)
    }

    @Test func thirtyIsTheDefault() {
        #expect(ClipPlan.frameRates == [30, 60])
        #expect(ClipPlan.defaultFrameRate == 30)
    }
}

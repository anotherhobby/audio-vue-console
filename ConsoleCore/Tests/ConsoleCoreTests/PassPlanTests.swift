import Testing

@testable import ConsoleCore

/// Design D5: a pass runs the host's rates the output offers, lowest first, and skips the rest.
struct PassPlanTests {
    private static let hostRates = [192_000, 44_100, 48_000, 88_200, 96_000]

    @Test func anOutputWithout192kHzSkipsIt() {
        let output = OutputDevice(uid: "o", name: "Out", availableRates: [44_100...96_000])
        let plan = PassPlan.make(hostRates: Self.hostRates, output: output)
        #expect(plan.runs == [44_100, 48_000, 88_200, 96_000])
        #expect(plan.skipped == [192_000])
    }

    @Test func noRateInCommonRunsNothing() {
        let output = OutputDevice(uid: "o", name: "Out", availableRates: [32_000...32_000])
        let plan = PassPlan.make(hostRates: Self.hostRates, output: output)
        #expect(plan.runs.isEmpty)
        #expect(plan.skipped == [44_100, 48_000, 88_200, 96_000, 192_000])
    }
}

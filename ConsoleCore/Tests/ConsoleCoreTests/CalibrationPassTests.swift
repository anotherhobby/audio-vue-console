import Foundation
import Testing

@testable import ConsoleCore

/// A calibration at every rate in one pass (`calibration-pass`, design D4), over the scripted host
/// and player the session's tests use.
@MainActor struct CalibrationPassTests {
    private typealias Rig = CalibrationSessionTests.Rig
    private static let cancelled = FakeTransport.Answer.status(200, #"{"status": "done"}"#)

    private static let d10s = OutputDevice(
        uid: "d10s", name: "D10s ", availableRates: [44_100...192_000])

    /// The D10s at 192 kHz, where a pass of every rate leaves it.
    private static func output() -> ScriptedOutputControl {
        ScriptedOutputControl([d10s], current: ["d10s": OutputCurrent(rate: 192_000, format: nil)])
    }

    private static func rig(output: ScriptedOutputControl = output()) -> (Rig, CalibrationPass) {
        let rig = CalibrationSessionTests.rig([
            .arm: CalibrationSessionTests.armed, .cancel: cancelled,
        ])
        let pass = CalibrationPass(session: rig.session, output: output)
        pass.observe(PanelState(condition: .up), isLive: true)
        return (rig, pass)
    }

    private static func start(
        _ pass: CalibrationPass, _ plan: PassPlan, kind: StatedRun.Kind = .calibration,
        returnTo: Int? = nil
    ) throws {
        let host = CalibrationHost(
            address: try #require(HostAddress(parsing: "audio-vue")), token: HostToken("secret"))
        #expect(pass.start(kind: kind, plan: plan, device: d10s, host: host, returnTo: returnTo))
    }

    /// Waits until the pass is playing `rate`'s file.
    private static func playing(_ pass: CalibrationPass, at rate: Int, _ rig: Rig) async throws {
        try await CalibrationSessionTests.waitUntil {
            pass.current?.rate == rate
                && CalibrationSessionTests.isPlaying(pass.session, on: rig.launcher)
        }
    }

    /// Ends the run under way as the panel would, by naming its arm.
    private static func end(
        _ pass: CalibrationPass, _ outcome: EndedCalibration.Outcome,
        condition: PanelState.Condition = .up
    ) {
        var state = CalibrationSessionTests.state(
            .off, ended: EndedCalibration(arm: "a1", outcome: outcome, runID: "r"))
        state.condition = condition
        pass.observe(state, isLive: true)
    }

    private static func finished(_ pass: CalibrationPass) async throws {
        try await CalibrationSessionTests.waitUntil { !pass.isUnderWay }
    }

    /// Each arm's stated `kind` and `file_rate`, in order.
    private static func arms(_ rig: Rig) async throws -> [[String: Any]] {
        try await rig.transport.requests(to: .arm).map { request in
            let body = try #require(request.httpBody)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            return try #require(json?["stated"] as? [String: Any])
        }
    }

    private static let completed = RateOutcome.ended(
        .completed(runID: "r", applicable: true, reason: nil))

    @Test func eachArmStatesItsRateLowestFirstAndNoInstallIsWritten() async throws {
        let (rig, pass) = Self.rig()
        try Self.start(pass, PassPlan(runs: [44_100, 48_000]))
        try await Self.playing(pass, at: 44_100, rig)
        #expect(pass.current == CalibrationPass.Place(rate: 44_100, index: 1, count: 2))
        Self.end(pass, .done)
        try await Self.playing(pass, at: 48_000, rig)
        Self.end(pass, .done)
        try await Self.finished(pass)
        let rates = try await Self.arms(rig).compactMap { $0["file_rate"] as? Int }
        #expect(rates == [44_100, 48_000])
        #expect(pass.outcomes.map(\.outcome) == [Self.completed, Self.completed])
        #expect(await rig.transport.requests.allSatisfy { $0.httpMethod != "PUT" })
    }

    @Test func anExpiredRateGoesOnToTheNext() async throws {
        let (rig, pass) = Self.rig()
        try Self.start(pass, PassPlan(runs: [88_200, 96_000]))
        try await Self.playing(pass, at: 88_200, rig)
        Self.end(pass, .expired)
        try await Self.playing(pass, at: 96_000, rig)
        Self.end(pass, .done)
        try await Self.finished(pass)
        #expect(pass.outcomes.first?.outcome == .ended(.expired(reason: nil)))
        #expect(pass.outcomes.last?.outcome == Self.completed)
    }

    @Test func cancelLeavesTheRatesAfterNotRun() async throws {
        let (rig, pass) = Self.rig()
        try Self.start(pass, PassPlan(runs: [96_000, 192_000]))
        try await Self.playing(pass, at: 96_000, rig)
        pass.cancel()
        try await Self.finished(pass)
        #expect(pass.outcomes.map(\.outcome) == [.ended(.cancelled), .notRun])
        #expect(await rig.transport.requests(to: .cancel).count == 1)
    }

    @Test func thePanelGoingDownEndsThePassAfterThatRun() async throws {
        let (rig, pass) = Self.rig()
        try Self.start(pass, PassPlan(runs: [44_100, 48_000]))
        try await Self.playing(pass, at: 44_100, rig)
        Self.end(pass, .done, condition: .down)
        try await Self.finished(pass)
        #expect(pass.outcomes.map(\.outcome) == [Self.completed, .notRun])
        #expect(await rig.transport.requests(to: .arm).count == 1)
    }

    @Test func thePassIsUnderWayBetweenTwoRates() async throws {
        let (rig, pass) = Self.rig()
        try Self.start(pass, PassPlan(runs: [44_100, 48_000]))
        try await Self.playing(pass, at: 44_100, rig)
        Self.end(pass, .done)
        #expect(!pass.session.isUnderWay)
        #expect(pass.isUnderWay)
        try await Self.playing(pass, at: 48_000, rig)
        pass.cancel()
        try await Self.finished(pass)
    }

    @Test func aOneRatePassOfACharacterizationArmsACharacterization() async throws {
        let (rig, pass) = Self.rig()
        try Self.start(pass, PassPlan(runs: [96_000]), kind: .characterization)
        try await Self.playing(pass, at: 96_000, rig)
        #expect(!pass.isMultiRate)
        #expect(try await Self.arms(rig).first?["kind"] as? String == "characterization")
        Self.end(pass, .done)
        try await Self.finished(pass)
    }

    /// Design D5: the outcomes are in the host's order, each skipped and not-run rate in place.
    @Test func theOutcomesAreInTheHostsOrder() async throws {
        let (rig, pass) = Self.rig()
        let plan = PassPlan(runs: [44_100, 48_000, 88_200, 96_000], skipped: [192_000])
        try Self.start(pass, plan)
        try await Self.playing(pass, at: 44_100, rig)
        Self.end(pass, .done)
        try await Self.playing(pass, at: 48_000, rig)
        pass.cancel()
        try await Self.finished(pass)
        #expect(pass.outcomes.map(\.rate) == [44_100, 48_000, 88_200, 96_000, 192_000])
        #expect(
            pass.outcomes.map(\.outcome) == [
                Self.completed, .ended(.cancelled), .notRun, .notRun, .skipped,
            ])
    }

    // MARK: The output after a pass (`mac-output` design D9)

    /// `mac-output`, "After a pass of every rate".
    @Test func aSynchronizedOutputReturnsToTheCaptureRate() async throws {
        let output = Self.output()
        let (rig, pass) = Self.rig(output: output)
        try Self.start(pass, PassPlan(runs: [192_000]), returnTo: 96_000)
        try await Self.playing(pass, at: 192_000, rig)
        Self.end(pass, .done)
        try await Self.finished(pass)
        #expect(output.rateSets == [96_000])
    }

    /// `mac-output`, "Not synchronized".
    @Test func anOutputNotSynchronizedStaysAtTheLastRate() async throws {
        let output = Self.output()
        let (rig, pass) = Self.rig(output: output)
        try Self.start(pass, PassPlan(runs: [192_000]))
        try await Self.playing(pass, at: 192_000, rig)
        Self.end(pass, .done)
        try await Self.finished(pass)
        #expect(output.rateSets.isEmpty)
    }

    @Test func anOutputAlreadyAtTheCaptureRateIsNotSet() async throws {
        let output = Self.output()
        let (rig, pass) = Self.rig(output: output)
        try Self.start(pass, PassPlan(runs: [192_000]), returnTo: 192_000)
        try await Self.playing(pass, at: 192_000, rig)
        Self.end(pass, .done)
        try await Self.finished(pass)
        #expect(output.rateSets.isEmpty)
    }

    @Test func aCancelledPassStillReturnsTheOutput() async throws {
        let output = Self.output()
        let (rig, pass) = Self.rig(output: output)
        try Self.start(pass, PassPlan(runs: [192_000, 96_000]), returnTo: 96_000)
        try await Self.playing(pass, at: 192_000, rig)
        pass.cancel()
        try await Self.finished(pass)
        #expect(output.rateSets == [96_000])
    }

    @Test func aRefusedReturnLeavesTheOutcomesAsTheyWere() async throws {
        let output = Self.output()
        output.refuse(with: .refused(-50))
        let (rig, pass) = Self.rig(output: output)
        try Self.start(pass, PassPlan(runs: [192_000]), returnTo: 96_000)
        try await Self.playing(pass, at: 192_000, rig)
        Self.end(pass, .done)
        try await Self.finished(pass)
        #expect(output.rateSets == [96_000])
        #expect(pass.outcomes.map(\.outcome) == [Self.completed])
    }
}

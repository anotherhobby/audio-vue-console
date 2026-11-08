import Foundation
import Testing

@testable import ConsoleCore

/// Whether Calibrate… can start, at which rate (`calibration-run`, design D4).
struct CalibrationReadinessTests {
    private static func readiness(
        paired: Bool = true, condition: PanelState.Condition? = .up,
        verdict: CardCodeVerdict? = .same, rate: Int? = 96_000, underWay: Bool = false
    ) -> CalibrationReadiness {
        CalibrationReadiness(
            paired: paired, condition: condition, verdict: verdict, installedRate: rate,
            underWay: underWay)
    }

    @Test func readyAtTheInstalledRate() {
        #expect(Self.readiness() == .ready(rate: 96_000))
    }

    @Test func aWrittenRateIsTheRunsWhateverTheSceneCapturesAt() throws {
        let install: [String: JSONValue] = ["input": .object(["rate": .integer(96_000)])]
        #expect(CalibrationRuns.rate(install: install, schema: Self.schema) == 96_000)
    }

    @Test func anUnwrittenRateTakesTheSchemasDefault() {
        #expect(
            CalibrationRuns.rate(install: ["input": .object([:])], schema: Self.schema) == 48_000)
        #expect(CalibrationRuns.rate(install: [:], schema: Self.schema) == 48_000)
    }

    @Test func differentCodeIsNotReady() {
        guard case .notReady(let reason) = Self.readiness(verdict: .unreadable) else {
            Issue.record("ready with code that could not be compared")
            return
        }
        #expect(reason.contains("different audio-vue code"))
    }

    @Test func aPanelNotUpIsNotReady() {
        #expect(
            Self.readiness(condition: .down)
                == .notReady("The panel isn't running, so it can't be calibrated."))
        #expect(Self.readiness(condition: .noAudio) != .ready(rate: 96_000))
    }

    @Test func notPairedOrUnderWayIsNotReady() {
        #expect(Self.readiness(paired: false) == .notReady("Pair with the panel to calibrate it."))
        #expect(Self.readiness(underWay: true) == .notReady("A run is under way."))
    }

    @Test func aRateNotYetReadIsNotReady() {
        #expect(Self.readiness(rate: nil) == .notReady("Reading the panel's capture rate…"))
    }

    private static let schema: JSONValue = .object([
        "$defs": .object([
            "install.input": .object([
                "properties": .object(["rate": .object(["default": .integer(48_000)])])
            ])
        ])
    ])
}

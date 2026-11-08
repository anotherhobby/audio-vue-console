import Foundation
import Testing

@testable import ConsoleCore

/// Cancel at each step of a run (`calibration-run`, "Cancel stops a run at any step").
@MainActor struct CalibrationSessionCancelTests {
    private typealias Rig = CalibrationSessionTests

    @Test func cancelWhileSettlingArmsNothing() async throws {
        let rig = Rig.rig(player: { _ in nil })
        try Rig.start(rig)
        try await Rig.waitUntil { rig.session.step == .settling && !rig.launcher.calls.isEmpty }
        rig.session.cancel()
        #expect(rig.session.ending == .cancelled)
        try await Rig.waitUntil { rig.launcher.players.first?.stopCount == 1 }
        #expect(await rig.transport.requests.isEmpty)
    }

    @Test func cancelWhilePlayingStopsTheChildAndSendsOneCancel() async throws {
        let rig = Rig.rig([.arm: Rig.armed, .cancel: .status(200, #"{"status": "done"}"#)])
        try Rig.start(rig)
        try await Rig.waitUntil { Rig.isPlaying(rig.session) }
        rig.session.cancel()
        try await Rig.waitUntil { rig.session.ending != nil }
        #expect(rig.session.ending == .cancelled)
        #expect(rig.launcher.players.last?.stopCount == 1)
        #expect(await rig.transport.requests(to: .cancel).count == 1)
    }

    @Test func aCancelAfterTheRunCompletedFollowsItToItsEnding() async throws {
        let stands = #"{"status": "done", "record_stands": true}"#
        let rig = Rig.rig([.arm: Rig.armed, .cancel: .status(200, stands)])
        try Rig.start(rig)
        try await Rig.waitUntil { Rig.isPlaying(rig.session) }
        rig.session.cancel()
        try await Rig.waitUntil { !Rig.isPlaying(rig.session) }
        #expect(rig.session.isUnderWay)
        let ended = EndedCalibration(arm: "a1", outcome: .done, runID: "r1", applicable: true)
        rig.session.observe(Rig.state(.off, ended: ended))
        #expect(rig.session.ending == .completed(runID: "r1", applicable: true, reason: nil))
    }

    @Test func aCancelTooLateShowsItsReasonAndKeepsTheRunGoing() async throws {
        let late = #"{"status": "refused", "reason": "too late -- the record is being written"}"#
        let rig = Rig.rig([.arm: Rig.armed, .cancel: .status(409, late)])
        try Rig.start(rig)
        try await Rig.waitUntil { Rig.isPlaying(rig.session) }
        rig.session.cancel()
        try await Rig.waitUntil { rig.session.note != nil }
        #expect(rig.session.note == "too late -- the record is being written")
        #expect(rig.session.isUnderWay)
        rig.session.observe(Rig.state(.done, ended: EndedCalibration(arm: "a1", outcome: .done)))
        #expect(rig.session.ending == .completed(runID: nil, applicable: true, reason: nil))
    }

    @Test func aFailedRunSaysWhy() async throws {
        let rig = Rig.rig()
        try Rig.start(rig)
        try await Rig.waitUntil { Rig.isPlaying(rig.session) }
        let ended = EndedCalibration(arm: "a1", outcome: .failed, reason: "capture stopped")
        rig.session.observe(Rig.state(.off, ended: ended))
        #expect(rig.session.ending == .failed(reason: "capture stopped"))
    }

    @Test func aCompletedRunThatCannotApplySaysWhichStimulus() async throws {
        let rig = Rig.rig()
        try Rig.start(rig)
        try await Rig.waitUntil { Rig.isPlaying(rig.session) }
        let missing = "the 997 Hz series at 41.2 s did not arrive"
        let ended = EndedCalibration(
            arm: "a1", outcome: .done, runID: "r2", applicable: false, reason: missing)
        rig.session.observe(Rig.state(.done, ended: ended))
        #expect(rig.session.ending == .completed(runID: "r2", applicable: false, reason: missing))
    }
}

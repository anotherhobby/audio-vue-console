import Foundation
import Testing

@testable import ConsoleCore

/// The state the Overview reads, from the host's state messages (`panel-window`; design D7).
struct PanelStateTests {
    /// A state as the proving host pushes it with the panel up, cut to the sections read.
    static let up = #"""
        {"schema": 3, "age_s": 0.1, "condition": "up", "since": "2026-11-05T14:02:11Z",
         "sections": {
           "scene": {"spec": "rta", "name": "RTA", "grid": {"cols": 64, "rows": 36}},
           "capture": {"open": true, "live": true, "device": "m2x4HD", "rate_hz": 96000},
           "analysis": {"p50_ms": 0.6, "p99_ms": 0.9, "max_ms": 1.4, "budget_ms": 5.3},
           "calibration": {"status": "calibrated", "age_days": 12.4},
           "display": {"stage": "scene", "width_px": 1920, "height_px": 1080}}}
        """#

    @Test func aWholeState() throws {
        let state = try PanelState(json: Data(Self.up.utf8))
        #expect(state.condition == .up)
        #expect(state.since == Date(timeIntervalSince1970: 1_793_887_331))
        #expect(state.sceneName == "RTA")
        #expect(state.captureDevice == "m2x4HD")
        #expect(state.rateHz == 96_000)
        #expect(state.analysisP99Ms == 0.9)
        #expect(state.analysisBudgetMs == 5.3)
        #expect(state.calibrationStatus == "calibrated")
        #expect(state.calibrationAgeDays == 12.4)
        #expect(state.displayWidthPx == 1920)
        #expect(state.displayHeightPx == 1080)
        #expect(state.unavailable.isEmpty)
    }

    @Test func aDownStateWithEmptySections() throws {
        let json =
            #"{"schema": null, "age_s": null, "condition": "down", "since": null, "sections": {}}"#
        let state = try PanelState(json: Data(json.utf8))
        #expect(state == PanelState(condition: .down))
    }

    @Test func aFailedSectionGivesItsReason() throws {
        let json = #"""
            {"condition": "up", "sections": {
              "capture": {"unavailable": "the device went away"},
              "scene": {"name": "RTA"}}}
            """#
        let state = try PanelState(json: Data(json.utf8))
        #expect(state.unavailable == [.capture: "the device went away"])
        #expect(state.captureDevice == nil)
        #expect(state.sceneName == "RTA")
    }

    @Test func unknownFieldsAreIgnored() throws {
        let json = #"""
            {"condition": "stale", "added": [1, 2], "sections": {
              "scene": {"name": "RTA", "new_field": {"x": 1}}, "new_section": {"y": true}}}
            """#
        let state = try PanelState(json: Data(json.utf8))
        #expect(state.condition == .stale)
        #expect(state.sceneName == "RTA")
    }

    @Test func somethingElseIsUnexpected() {
        #expect(throws: HostFailure.unexpectedAnswer) {
            try PanelState(json: Data(#"{"condition": "sideways", "sections": {}}"#.utf8))
        }
    }
}

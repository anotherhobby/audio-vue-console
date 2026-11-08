import Foundation
import Testing

@testable import ConsoleCore

/// The calibration in force as the Calibration page says it (`calibration-history`).
struct CalibrationRowsTests {
    private static func values(_ rows: CalibrationRows) -> [String: String] {
        Dictionary(uniqueKeysWithValues: rows.inForce.rows.map { ($0.label, $0.value) })
    }

    @Test func aCalibratedPanel() throws {
        let json = #"""
            {"condition": "up", "sections": {"calibration": {
              "status": "calibrated", "run_id": "2026-10-25T23-16-08Z", "age_days": 14.2,
              "trim_db": 0.01, "noise_floor_dbfs": -118.43}}}
            """#
        let rows = CalibrationRows(state: try PanelState(json: Data(json.utf8)))
        #expect(
            Self.values(rows) == [
                "Status": "Calibrated", "Run": RunEntry.title(forID: "2026-10-25T23-16-08Z"),
                "Age": "14 days",
                "Trim": "+0.01 dB", "Noise Floor": "-118.4 dBFS",
            ])
        #expect(rows.inForce.note == nil)
    }

    @Test func theRunInForceIsNamedAsTheRunsListNamesIt() throws {
        let id = "2026-11-08T18-41-37Z"
        let json = #"{"condition": "up", "sections": {"calibration": {"run_id": "\#(id)"}}}"#
        let rows = CalibrationRows(state: try PanelState(json: Data(json.utf8)))
        let run = RunEntry(id: id, hasReport: true, kind: "characterization")
        #expect(Self.values(rows)["Run"] == run.title)
        #expect(run.title != id)
        #expect(run.title == run.date?.formatted(date: .abbreviated, time: .standard))
    }

    @Test func whyNoneApplies() throws {
        let json = #"{"condition": "up", "sections": {"calibration": {"status": "obsolete"}}}"#
        let rows = CalibrationRows(state: try PanelState(json: Data(json.utf8)))
        #expect(Self.values(rows)["Status"] == "Obsolete")
        #expect(Self.values(rows)["Trim"] == PanelRows.dash)
    }

    @Test func everyValueIsADashWithThePanelDown() {
        let down = CalibrationRows(state: PanelState(condition: .down))
        let unread = CalibrationRows(state: nil)
        #expect(down.inForce.rows.allSatisfy { $0.value == PanelRows.dash })
        #expect(unread == down)
    }
}

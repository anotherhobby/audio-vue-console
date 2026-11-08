import Foundation
import Testing

@testable import ConsoleCore

/// The host's calibration runs and their reports (`calibration-history`).
struct HostClientCalibrationTests {
    private let token = HostToken("secret")

    private func address() throws -> HostAddress {
        try #require(HostAddress(parsing: "audio-vue"))
    }

    @Test func theRunsInTheHostsOrderWithTheirKindsAndTheToken() async throws {
        let body = #"""
            {"runs": [
              {"run_id": "2026-11-01T14-55-02Z", "has_report": true, "kind": "calibration",
               "applicable": true},
              {"run_id": "2026-10-25T23-16-08Z", "has_report": false,
               "kind": "characterization", "applicable": false}]}
            """#
        let transport = FakeTransport([.runs: .status(200, body)])
        let runs = try await HostClient(transport: transport).runs(at: try address(), token: token)
        #expect(
            runs == [
                RunEntry(id: "2026-11-01T14-55-02Z", hasReport: true, kind: "calibration"),
                RunEntry(id: "2026-10-25T23-16-08Z", hasReport: false, kind: "characterization"),
            ])
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }

    @Test func aReportsHTML() async throws {
        let html = "<html><body><h1>Calibration</h1></body></html>"
        let transport = FakeTransport([
            .report("2026-11-01T14-55-02Z"): .status(
                200, html, headers: ["Content-Type": "text/html; charset=utf-8"])
        ])
        let report = try await HostClient(transport: transport).report(
            "2026-11-01T14-55-02Z", at: try address(), token: token)
        #expect(report == html)
    }

    @Test func aReportNotThere() async throws {
        let transport = FakeTransport([
            .report("nope"): .status(
                404, #"{"detail": "no such run"}"#, headers: ["Content-Type": "text/html"])
        ])
        await #expect(throws: HostFailure.notFound) {
            _ = try await HostClient(transport: transport).report(
                "nope", at: try address(), token: token)
        }
    }

    @Test func aRunsDateIsReadFromItsIdInUTC() {
        let run = RunEntry(id: "2026-10-25T23-16-08Z", hasReport: true, kind: "calibration")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let expected = utc.date(
            from: DateComponents(year: 2026, month: 10, day: 25, hour: 23, minute: 16, second: 8))
        #expect(run.date == expected)
    }

    @Test func anIdThatIsNotATimeHasNoDate() {
        #expect(RunEntry(id: "manual-1", hasReport: false, kind: "calibration").date == nil)
    }
}

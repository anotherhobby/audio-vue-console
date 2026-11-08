import Foundation
import HostAPI
import OpenAPIRuntime

/// A calibration run as the host lists it (`calibration-history`).
public struct RunEntry: Sendable, Hashable, Identifiable {
    /// The run's id, its start in UTC as `2026-10-25T23-16-08Z`.
    public let id: String
    public let hasReport: Bool
    /// `calibration` or `characterization`, as the host says.
    public let kind: String

    public init(id: String, hasReport: Bool, kind: String) {
        self.id = id
        self.hasReport = hasReport
        self.kind = kind
    }

    /// When the run started, read from its id; nil where the id is not a date and time.
    public var date: Date? { Self.date(fromID: id) }

    /// The run as the app names it everywhere: its start in this Mac's time zone, or its id where
    /// that is not a date and time.
    public var title: String { Self.title(forID: id) }

    /// The title of the run `id` names, as the runs list and the calibration in force show it.
    public static func title(forID id: String) -> String {
        date(fromID: id)?.formatted(date: .abbreviated, time: .standard) ?? id
    }

    static func date(fromID id: String) -> Date? {
        do {
            return try Date(id, strategy: idFormat)
        } catch {
            return nil
        }
    }

    private static let idFormat = Date.ParseStrategy(
        format: """
            \(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)T\
            \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))-\
            \(minute: .twoDigits)-\(second: .twoDigits)Z
            """,
        timeZone: .gmt)
}

/// The host's calibration runs and their reports, read with a token (audio-vue `control-api`,
/// "Calibration runs are served from their files").
extension HostClient {
    /// `GET /v1/runs`: every run with a record, newest first, as the host orders them.
    public func runs(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> [RunEntry]
    {
        let output = try await call(at: address, token: token) { try await $0.listingV1RunsGet() }
        switch output {
        case .ok(let ok):
            return try Self.body { try ok.body.json }.runs.map {
                RunEntry(id: $0.runId, hasReport: $0.hasReport, kind: $0.kind)
            }
        case .unauthorized, .undocumented: throw .unexpectedAnswer
        }
    }

    /// `GET /v1/runs/{run_id}/report`: a run's HTML report, as the host wrote it.
    public func report(_ runID: String, at address: HostAddress, token: HostToken)
        async throws(HostFailure) -> String
    {
        let output = try await call(at: address, token: token) {
            try await $0.reportV1RunsRunIdReportGet(path: .init(runId: runID))
        }
        switch output {
        case .ok(let ok):
            let body = try Self.body { try ok.body.html }
            let data: Data
            do {
                data = try await Data(collecting: body, upTo: Self.reportLimit)
            } catch {
                throw .unexpectedAnswer
            }
            guard let html = String(bytes: data, encoding: .utf8) else { throw .unexpectedAnswer }
            return html
        case .notFound: throw .notFound
        case .unauthorized, .unprocessableContent, .undocumented: throw .unexpectedAnswer
        }
    }

    /// The largest report the app takes, 16 MiB, far over the 77 KB one measured (2026-11-08).
    static let reportLimit = 16_777_216
}

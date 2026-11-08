import Foundation
import Testing

@testable import ConsoleCore

/// A calibration's arm and cancel, with what a run states (`calibration-run`, design D3).
struct HostClientCalibrationCommandsTests {
    private let token = HostToken("secret")

    private func address() throws -> HostAddress {
        try #require(HostAddress(parsing: "audio-vue"))
    }

    /// A request's JSON body, compared as JSON.
    private static func body(of request: URLRequest) throws -> NSDictionary {
        let data = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    @Test func anArmStatesTheKindAndRateWithTheToken() async throws {
        let done = #"{"status": "done", "listening": true, "deadline_s": 10, "arm": "a7"}"#
        let transport = FakeTransport([.arm: .status(200, done)])
        let answer = try await HostClient(transport: transport).arm(
            StatedRun(rate: 96_000), at: try address(), token: token)
        #expect(answer == ArmAnswer(outcome: .done(nil), arm: "a7"))
        let request = try #require(await transport.requests.first)
        #expect(
            try Self.body(of: request)
                == ["stated": ["kind": "calibration", "file_rate": 96_000]] as NSDictionary)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }

    @Test func aCharacterizationArmStatesItsKind() async throws {
        let transport = FakeTransport([.arm: .status(200, #"{"status": "done", "arm": "a8"}"#)])
        let run = StatedRun(kind: .characterization, rate: 48_000)
        _ = try await HostClient(transport: transport).arm(run, at: try address(), token: token)
        let request = try #require(await transport.requests.first)
        let stated: NSDictionary = ["kind": "characterization", "file_rate": 48_000]
        #expect(try Self.body(of: request) == ["stated": stated] as NSDictionary)
    }

    @Test func aRefusedArmGivesItsReasonAndNoId() async throws {
        let refused = #"{"status": "refused", "reason": "still arming"}"#
        let transport = FakeTransport([.arm: .status(409, refused)])
        let answer = try await HostClient(transport: transport).arm(
            StatedRun(rate: 96_000), at: try address(), token: token)
        #expect(answer == ArmAnswer(outcome: .refused("still arming"), arm: nil))
    }

    @Test func aCancelAfterACompletedRunSaysItsRecordStands() async throws {
        let done = #"{"status": "done", "record_stands": true}"#
        let transport = FakeTransport([.cancel: .status(200, done)])
        let answer = try await HostClient(transport: transport).cancelCalibration(
            at: try address(), token: token)
        #expect(answer == CancelAnswer(outcome: .done(nil), recordStands: true))
    }

    @Test func aCancelTooLate() async throws {
        let refused = #"{"status": "refused", "reason": "too late -- the record is being written"}"#
        let transport = FakeTransport([.cancel: .status(409, refused)])
        let answer = try await HostClient(transport: transport).cancelCalibration(
            at: try address(), token: token)
        #expect(
            answer
                == CancelAnswer(
                    outcome: .refused("too late -- the record is being written"),
                    recordStands: false))
    }
}

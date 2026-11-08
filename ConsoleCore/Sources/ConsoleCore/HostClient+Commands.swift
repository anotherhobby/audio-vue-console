import Foundation
import HostAPI
import OpenAPIRuntime

/// What became of a command the panel was asked for (audio-vue `control-api`, "A command says what
/// became of it"): done, refused with the panel's reason, no panel to answer, or expired or unknown,
/// when it may or may not have been done.
public enum CommandOutcome: Sendable, Equatable {
    /// Done; for a switch, what it cost, where the panel said.
    case done(SwitchResult?)
    case refused(String)
    case noPanel
    case expired(String)
    case unknown(String)
}

/// What a done switch cost (design D8): whether capture was kept or rebuilt, what forced a rebuild
/// in words for a person, and whether the scene became the panel's next start.
public struct SwitchResult: Sendable, Equatable {
    public enum Capture: Sendable, Equatable {
        case kept
        case rebuilt
    }

    public let capture: Capture
    public let why: String?
    public let recorded: Bool

    public init(capture: Capture, why: String?, recorded: Bool) {
        self.capture = capture
        self.why = why
        self.recorded = recorded
    }
}

/// The panel's commands the app sends (`scene-apply`): a switch to a scene, and a reset.
extension HostClient {
    /// `POST /v1/commands/switch`: puts the scene `id` up, a stored scene at its current revision.
    public func switchScene(_ id: String, at address: HostAddress, token: HostToken)
        async throws(HostFailure) -> CommandOutcome
    {
        let output = try await call(at: address, token: token) {
            try await $0.switchV1CommandsSwitchPost(body: .json(.init(scene: id)))
        }
        switch output {
        case .ok(let ok):
            let body = try Self.body { try ok.body.json }
            guard body.status == .done else {
                return Self.outcome(body.status.rawValue, reason: body.reason)
            }
            return .done(
                body.capture.map {
                    SwitchResult(
                        capture: $0 == .rebuilt ? .rebuilt : .kept, why: body.why,
                        recorded: body.recorded ?? true)
                })
        case .conflict(let answer): return try Self.outcome(answer.body.json)
        case .serviceUnavailable(let answer): return try Self.outcome(answer.body.json)
        case .gatewayTimeout(let answer): return try Self.outcome(answer.body.json)
        case .unauthorized, .unprocessableContent, .undocumented: throw .unexpectedAnswer
        }
    }

    /// `POST /v1/commands/reset`: restarts the panel's measurement.
    public func resetPanel(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> CommandOutcome
    {
        let output = try await call(at: address, token: token) {
            try await $0.resetV1CommandsResetPost()
        }
        switch output {
        case .ok(let answer): return try Self.outcome(answer.body.json)
        case .conflict(let answer): return try Self.outcome(answer.body.json)
        case .serviceUnavailable(let answer): return try Self.outcome(answer.body.json)
        case .gatewayTimeout(let answer): return try Self.outcome(answer.body.json)
        case .unauthorized, .undocumented: throw .unexpectedAnswer
        }
    }

    /// An `Outcome` as the app reads it, by its status.
    private static func outcome(_ read: @autoclosure () throws -> Components.Schemas.Outcome)
        throws(HostFailure) -> CommandOutcome
    {
        let body = try Self.body(read)
        return outcome(body.status.rawValue, reason: body.reason)
    }

    /// The outcome a status names, with the panel's reason where it gave one.
    private static func outcome(_ status: String, reason: String?) -> CommandOutcome {
        let reason = reason ?? ""
        switch status {
        case "done": return .done(nil)
        case "refused": return .refused(reason)
        case "no panel": return .noPanel
        case "expired": return .expired(reason)
        default: return .unknown(reason)
        }
    }
}

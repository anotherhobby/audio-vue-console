import Foundation
import HostAPI

/// What a host said when asked for a code: how long the code on its panel stands, and how many
/// wrong codes it takes before withdrawing it.
public struct PairingCode: Sendable, Equatable {
    public let ttl: TimeInterval
    public let tries: Int

    public init(ttl: TimeInterval, tries: Int) {
        self.ttl = ttl
        self.tries = tries
    }
}

/// What confirming a code gives, once: the token and this app's id as the host's client.
public struct PairingGrant: Sendable, Equatable {
    public let token: HostToken
    public let clientID: String
}

/// The host's `GET /v1/host`: its id, stable across addresses and restarts, its name, and the
/// panel's display size, which is nil unless a running panel says it.
public struct HostIdentity: Sendable, Equatable {
    public let id: String
    public let name: String
    public let widthPx: Int?
    public let heightPx: Int?

    public init(id: String, name: String, widthPx: Int?, heightPx: Int?) {
        self.id = id
        self.name = name
        self.widthPx = widthPx
        self.heightPx = heightPx
    }
}

/// Why a host refused a pairing: the kind, from the call and the status, and the host's own
/// reason, worded for people (design D5).
public struct PairingRefusal: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// Asking: another client's code is showing.
        case busy
        /// Asking: too soon after the last pairing, with the seconds to wait where the host says.
        case tooSoon(seconds: Int?)
        /// Asking: the panel can't show a code, not running or not willing.
        case noPanel
        /// Confirming: the code is not the one showing.
        case wrongCode
        /// Confirming: no code is showing, since it lapsed or was withdrawn.
        case noCode
    }

    public let kind: Kind
    public let detail: String

    public init(_ kind: Kind, detail: String) {
        self.kind = kind
        self.detail = detail
    }
}

/// Pairing: asking for a code, confirming it, and reading the host it gave a token for. The two
/// pairing calls take no token, so `HostRules` sends none with them.
extension HostClient {
    /// `POST /v1/pairing`: asks the host to show a code on its panel, naming this app `name`.
    public func askPairing(at address: HostAddress, name: String) async throws(HostFailure)
        -> PairingCode
    {
        let output = try await call(at: address) {
            try await $0.askV1PairingPost(body: .json(.init(name: name)))
        }
        switch output {
        case .ok(let ok):
            let shown = try Self.body { try ok.body.json }
            return PairingCode(ttl: shown.ttlS, tries: shown.tries)
        case .conflict(let refused):
            throw .refusal(.busy, try Self.body { try refused.body.json })
        case .tooManyRequests(let refused):
            let seconds = refused.headers.retryAfter
            throw .refusal(.tooSoon(seconds: seconds), try Self.body { try refused.body.json })
        case .serviceUnavailable(let refused):
            throw .refusal(.noPanel, try Self.body { try refused.body.json })
        case .unprocessableContent, .undocumented: throw .unexpectedAnswer
        }
    }

    /// `POST /v1/pairing/confirm`: sends the code the user read off the panel, for a token.
    public func confirmPairing(at address: HostAddress, code: String) async throws(HostFailure)
        -> PairingGrant
    {
        let output = try await call(at: address) {
            try await $0.confirmV1PairingConfirmPost(body: .json(.init(code: code)))
        }
        switch output {
        case .ok(let ok):
            let body = try Self.body { try ok.body.json }
            return PairingGrant(token: HostToken(body.token), clientID: body.clientId)
        case .forbidden(let refused):
            throw .refusal(.wrongCode, try Self.body { try refused.body.json })
        case .conflict(let refused):
            throw .refusal(.noCode, try Self.body { try refused.body.json })
        case .unprocessableContent, .undocumented: throw .unexpectedAnswer
        }
    }

    /// `GET /v1/host`, which takes a token: the host's identity.
    public func host(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> HostIdentity
    {
        let output = try await call(at: address, token: token) { try await $0.identityV1HostGet() }
        guard case .ok(let ok) = output else { throw .unexpectedAnswer }
        let host = try Self.body { try ok.body.json }
        return HostIdentity(
            id: host.id, name: host.name, widthPx: host.widthPx, heightPx: host.heightPx)
    }
}

extension HostFailure {
    /// A pairing refused, with the host's reason, worded for people.
    fileprivate static func refusal(_ kind: PairingRefusal.Kind, _ body: Components.Schemas.Refusal)
        -> HostFailure
    {
        .pairingRefused(PairingRefusal(kind, detail: body.detail))
    }
}

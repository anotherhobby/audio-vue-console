import Foundation

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
public struct HostIdentity: Sendable, Equatable, Decodable {
    public let id: String
    public let name: String
    public let widthPx: Int?
    public let heightPx: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case widthPx = "width_px"
        case heightPx = "height_px"
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
/// pairing calls take no token, so none can be sent with them.
extension HostClient {
    /// `POST /v1/pairing`: asks the host to show a code on its panel, naming this app `name`.
    public func askPairing(at address: HostAddress, name: String) async throws(HostFailure)
        -> PairingCode
    {
        struct Asked: Encodable { let name: String }
        struct Shown: Decodable {
            let ttlS: Double
            let tries: Int
            enum CodingKeys: String, CodingKey {
                case ttlS = "ttl_s"
                case tries
            }
        }
        let (data, response) = try await send(
            .post, "v1/pairing", at: address, body: Asked(name: name))
        switch response.statusCode {
        case HTTPStatus.ok:
            let shown = try Self.decode(Shown.self, from: data)
            return PairingCode(ttl: shown.ttlS, tries: shown.tries)
        case HTTPStatus.conflict: throw Self.refusal(.busy, data)
        case HTTPStatus.tooManyRequests:
            let seconds = response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw Self.refusal(.tooSoon(seconds: seconds), data)
        case HTTPStatus.serviceUnavailable: throw Self.refusal(.noPanel, data)
        default: throw .unexpectedAnswer
        }
    }

    /// `POST /v1/pairing/confirm`: sends the code the user read off the panel, for a token.
    public func confirmPairing(at address: HostAddress, code: String) async throws(HostFailure)
        -> PairingGrant
    {
        struct Confirmed: Encodable { let code: String }
        struct Token: Decodable {
            let token: String
            let clientID: String
            enum CodingKeys: String, CodingKey {
                case token
                case clientID = "client_id"
            }
        }
        let (data, response) = try await send(
            .post, "v1/pairing/confirm", at: address, body: Confirmed(code: code))
        switch response.statusCode {
        case HTTPStatus.ok:
            let body = try Self.decode(Token.self, from: data)
            return PairingGrant(token: HostToken(body.token), clientID: body.clientID)
        case HTTPStatus.forbidden: throw Self.refusal(.wrongCode, data)
        case HTTPStatus.conflict: throw Self.refusal(.noCode, data)
        default: throw .unexpectedAnswer
        }
    }

    /// `GET /v1/host`, which takes a token: the host's identity.
    public func host(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> HostIdentity
    {
        let (data, response) = try await send(.get, "v1/host", at: address, token: token)
        guard response.statusCode == HTTPStatus.ok else { throw .unexpectedAnswer }
        return try Self.decode(HostIdentity.self, from: data)
    }

    private static func refusal(_ kind: PairingRefusal.Kind, _ data: Data) -> HostFailure {
        .pairingRefused(PairingRefusal(kind, detail: detail(in: data)))
    }
}

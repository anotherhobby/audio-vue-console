import Foundation

/// What a host's `GET /v1/version` says: its API's version, and the state's schema, which is nil
/// where the panel does not answer.
public struct HostVersion: Sendable, Equatable {
    public let api: APIVersion
    public let schema: Int?

    public init(api: APIVersion, schema: Int?) {
        self.api = api
        self.schema = schema
    }
}

/// Why reading a host failed, in the kinds `host-connection` tells apart.
public enum HostFailure: Error, Sendable, Equatable {
    /// Nothing answered at the address, or it did not answer in time.
    case unreachable
    /// The host answered 403, which it gives a request carrying an `Origin` header.
    case refused
    /// Something answered, but not as the contract says: another status, or a body that is not the
    /// call's answer.
    case unexpectedAnswer
    /// The host answered 401 to a request carrying a token: it no longer takes the token, so the
    /// app has to pair again. A request with no token never fails this way.
    case tokenRefused
    /// The host refused a pairing, saying why.
    case pairingRefused(PairingRefusal)
    /// The host lists no client by the id the request named.
    case unknownClient
}

/// Reads a host agent over its API. Every request it builds carries no `Origin` header, since the
/// host refuses any that does. The calls are grouped by subject in extensions.
public struct HostClient: Sendable {
    private let transport: any HostTransport

    public init(transport: any HostTransport = URLSessionTransport()) {
        self.transport = transport
    }

    /// The host's `GET /v1/version`, an open read.
    public func version(at address: HostAddress) async throws(HostFailure) -> HostVersion {
        let (data, response) = try await send(.get, "v1/version", at: address)
        switch response.statusCode {
        case HTTPStatus.ok:
            let body = try Self.decode(VersionBody.self, from: data)
            guard let api = APIVersion(parsing: body.api) else { throw .unexpectedAnswer }
            return HostVersion(api: api, schema: body.schema)
        case HTTPStatus.forbidden: throw .refused
        default: throw .unexpectedAnswer
        }
    }

    enum Method: String {
        case get = "GET"
        case post = "POST"
        case delete = "DELETE"
    }

    /// Sends one request and answers what came back, whatever its status, except that a 401 to a
    /// request carrying a token is `tokenRefused`. A body goes as JSON, a token as `Authorization:
    /// Bearer`, and no request has an `Origin`.
    func send(
        _ method: Method, _ path: String, at address: HostAddress, body: (any Encodable)? = nil,
        token: HostToken? = nil
    ) async throws(HostFailure) -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: address.url(path: path))
        request.httpMethod = method.rawValue
        request.setValue(Self.json, forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try Self.encode(body)
            request.setValue(Self.json, forHTTPHeaderField: "Content-Type")
        }
        if let token {
            request.setValue("Bearer \(token.value)", forHTTPHeaderField: "Authorization")
        }
        let answer: (Data, HTTPURLResponse)
        do {
            answer = try await transport.send(request)
        } catch let error as URLError where Self.unanswered.contains(error.code) {
            throw .unreachable
        } catch {
            throw .unexpectedAnswer
        }
        if token != nil, answer.1.statusCode == HTTPStatus.unauthorized { throw .tokenRefused }
        return answer
    }

    private static let json = "application/json"

    /// The transport errors that mean no host answered, as against one answering badly. A denial of
    /// local network access arrives as one of these too (`design.md`).
    private static let unanswered: Set<URLError.Code> = [
        .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
        .networkConnectionLost, .notConnectedToInternet,
    ]

    /// The version's fields; any others are ignored, since the contract leaves the object open.
    private struct VersionBody: Decodable {
        let api: String
        let schema: Int?
    }

    /// A body the contract gives; one that is not is an unexpected answer.
    static func decode<Body: Decodable>(_ type: Body.Type, from data: Data) throws(HostFailure)
        -> Body
    {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw .unexpectedAnswer
        }
    }

    /// The host's reason in a refusal's `{"detail": …}`, or nothing where the body has none.
    static func detail(in data: Data) -> String {
        struct Refusal: Decodable { let detail: String }
        do {
            return try JSONDecoder().decode(Refusal.self, from: data).detail
        } catch {
            return ""
        }
    }

    /// The JSON of a request's body. The bodies are the contract's string fields, which always
    /// encode; a failure is reported as the request going wrong.
    private static func encode(_ body: any Encodable) throws(HostFailure) -> Data {
        do {
            return try JSONEncoder().encode(body)
        } catch {
            throw .unexpectedAnswer
        }
    }
}

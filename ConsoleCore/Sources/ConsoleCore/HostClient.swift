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
    /// Something answered, but not with a version: another status, or a body that is not one.
    case unexpectedAnswer
}

/// Reads a host agent over its API. Every request it builds carries no `Origin` header, since the
/// host refuses any that does.
public struct HostClient: Sendable {
    private let transport: any HostTransport

    public init(transport: any HostTransport = URLSessionTransport()) {
        self.transport = transport
    }

    /// The host's `GET /v1/version`, an open read.
    public func version(at address: HostAddress) async throws(HostFailure) -> HostVersion {
        var request = URLRequest(url: address.url(path: "v1/version"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.get(request)
        } catch let error as URLError where Self.unanswered.contains(error.code) {
            throw .unreachable
        } catch {
            throw .unexpectedAnswer
        }
        switch response.statusCode {
        case Self.ok: return try Self.decode(data)
        case Self.forbidden: throw .refused
        default: throw .unexpectedAnswer
        }
    }

    private static let ok = 200
    private static let forbidden = 403

    /// The transport errors that mean no host answered, as against one answering badly. A denial of
    /// local network access arrives as one of these too (`design.md`).
    private static let unanswered: Set<URLError.Code> = [
        .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
        .networkConnectionLost, .notConnectedToInternet,
    ]

    /// The body's fields; any others are ignored, since the contract leaves the object open.
    private struct Body: Decodable {
        let api: String
        let schema: Int?
    }

    private static func decode(_ data: Data) throws(HostFailure) -> HostVersion {
        let body: Body
        do {
            body = try JSONDecoder().decode(Body.self, from: data)
        } catch {
            throw .unexpectedAnswer
        }
        guard let api = APIVersion(parsing: body.api) else { throw .unexpectedAnswer }
        return HostVersion(api: api, schema: body.schema)
    }
}

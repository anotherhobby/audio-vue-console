import Foundation
import HostAPI
import OpenAPIRuntime
import OpenAPIURLSession

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

/// Reads a host agent over its API, through the client generated from the saved contract (design
/// D2). Each call builds a generated client for its address and token, with `HostRules` applying
/// the host's rules to it, and turns the generated answer into this package's own values. The
/// calls are grouped by subject in extensions.
public struct HostClient: Sendable {
    private let transport: any ClientTransport

    /// A client over the app's URLSession.
    public init() {
        self.init(transport: Self.sessionTransport())
    }

    init(transport: any ClientTransport) {
        self.transport = transport
    }

    /// The host's `GET /v1/version`, an open read.
    public func version(at address: HostAddress) async throws(HostFailure) -> HostVersion {
        let output = try await call(at: address) { try await $0.versionV1VersionGet() }
        switch output {
        case .ok(let ok):
            let body = try Self.body { try ok.body.json }
            guard let api = APIVersion(parsing: body.api) else { throw .unexpectedAnswer }
            return HostVersion(api: api, schema: body.schema)
        case .undocumented(statusCode: Self.forbidden, _): throw .refused
        case .undocumented: throw .unexpectedAnswer
        }
    }

    /// Runs one operation on a generated client for `address`, carrying `token` where the
    /// operation takes one. A failure is told apart as `HostFailure` says: no host answering, a
    /// token refused, or anything else the host did that the contract does not say.
    func call<Output: Sendable>(
        at address: HostAddress, token: HostToken? = nil,
        _ operation: @Sendable (Client) async throws -> Output
    ) async throws(HostFailure) -> Output {
        let client = Client(
            serverURL: address.serverURL, transport: transport,
            middlewares: [HostRules(token: token)])
        do {
            return try await operation(client)
        } catch let error as ClientError {
            throw Self.failure(error.underlyingError)
        } catch {
            throw Self.failure(error)
        }
    }

    /// A response's body as the contract gives it. The generated client has already decoded it, so
    /// this fails only where the host sent another content type.
    static func body<Body>(_ read: () throws -> Body) throws(HostFailure) -> Body {
        do {
            return try read()
        } catch {
            throw .unexpectedAnswer
        }
    }

    private static func failure(_ error: any Error) -> HostFailure {
        if error is HostRules.TokenRefused { return .tokenRefused }
        if let error = error as? URLError, unanswered.contains(error.code) { return .unreachable }
        return .unexpectedAnswer
    }

    private static let forbidden = 403
    /// How long a host has to answer before it counts as not there.
    static let requestTimeout: TimeInterval = 5

    /// An ephemeral session that keeps no cookies or cache between requests, and gives up on a host
    /// that does not answer in `requestTimeout`.
    private static func sessionTransport() -> URLSessionTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSessionTransport(
            configuration: .init(session: URLSession(configuration: configuration)))
    }

    /// The transport errors that mean no host answered, as against one answering badly. A denial of
    /// local network access arrives as one of these too.
    private static let unanswered: Set<URLError.Code> = [
        .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
        .networkConnectionLost, .notConnectedToInternet,
    ]
}

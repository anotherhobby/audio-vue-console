import Foundation
import HostAPI
import OpenAPIRuntime
import OpenAPIURLSession

/// What a host's `GET /v1/version` says: its API's version, the state's schema, which is nil
/// where the panel does not answer, and the digest of the code the panel draws with.
public struct HostVersion: Sendable, Equatable {
    public let api: APIVersion
    public let schema: Int?
    public let cards: CardCode

    public init(api: APIVersion, schema: Int?, cards: CardCode) {
        self.api = api
        self.schema = schema
        self.cards = cards
    }
}

/// The digest of the code a panel draws scenes with, and where the host read it: from the running
/// panel, or from its own files where the panel does not answer, which is the code the panel will
/// run at its next start (`card-code`).
public struct CardCode: Sendable, Equatable {
    public enum Source: Sendable, Equatable {
        case panel
        case host
    }

    public let digest: String
    public let source: Source

    public init(digest: String, source: Source) {
        self.digest = digest
        self.source = source
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
    /// The host holds no scene or image by the id the request named.
    case notFound
    /// A write named a base revision the document has moved on from, which is now `currentRev`.
    case stale(currentRev: Int)
    /// The host refused a document as invalid, with every failure it found.
    case invalid([DocumentFailure])
    /// The host refused the request, saying why in words for a person, such as a delete of the
    /// scene on screen.
    case conflict(String)
}

/// One thing wrong with a document the host refused: where, the empty place being the document
/// itself, and what.
public struct DocumentFailure: Sendable, Equatable {
    public let place: String
    public let message: String

    public init(place: String, message: String) {
        self.place = place
        self.message = message
    }
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
            let source: CardCode.Source = body.cards.from == .panel ? .panel : .host
            return HostVersion(
                api: api, schema: body.schema,
                cards: CardCode(digest: body.cards.digest, source: source))
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

extension CardCode {
    /// A stand-in for previews, which show a version but compare no code.
    public static let preview = CardCode(digest: "preview", source: .panel)
}

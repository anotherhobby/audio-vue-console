import Foundation

/// What `HostClient` sends its requests through: any method, answered with a body and an HTTP
/// response. Tests put a fake here, so they see the very request the client built.
public protocol HostTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// The real transport: an ephemeral `URLSession` that keeps no cookies or cache between requests,
/// and gives up on a host that does not answer in five seconds.
public struct URLSessionTransport: HostTransport {
    public static let requestTimeout: TimeInterval = 5

    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Self.requestTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        request.timeoutInterval = Self.requestTimeout
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

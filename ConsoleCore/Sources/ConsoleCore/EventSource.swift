import Foundation

/// How one events socket ended, where it did not end by being cancelled.
public enum EventsEnd: Error, Sendable, Equatable {
    /// The host refused the handshake: by close code 1008 or an HTTP 403, which a wrong token and
    /// an `Origin` header both earn (design D6).
    case refused
    /// The socket closed or failed after it opened, or could not be opened at all.
    case closed
}

/// Where `LiveState` gets the host's pushed state: one socket per call, each message's bytes until
/// it ends with `EventsEnd`. Tests script one; the app opens a WebSocket.
public protocol EventSource: Sendable {
    func messages(at address: HostAddress, token: HostToken) -> AsyncThrowingStream<Data, any Error>
}

/// `/v1/events` over a `URLSessionWebSocketTask`. A socket that goes quiet is `LiveState`'s to
/// close, by its own timer (design D6).
public struct WebSocketEventSource: EventSource {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = HostClient.requestTimeout
        session = URLSession(configuration: configuration)
    }

    public func messages(at address: HostAddress, token: HostToken)
        -> AsyncThrowingStream<Data, any Error>
    {
        let task = session.webSocketTask(with: Self.handshake(at: address, token: token))
        return AsyncThrowingStream { continuation in
            let reading = Task {
                task.resume()
                do {
                    while true {
                        continuation.yield(Self.bytes(of: try await task.receive()))
                    }
                } catch {
                    continuation.finish(throwing: Self.end(of: task))
                }
            }
            continuation.onTermination = { _ in
                reading.cancel()
                task.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    /// The handshake: the token as `Authorization: Bearer`, as `HostRules` sends it, and no
    /// `Origin`, which URLSession does not add (checked against the proving host, task 4.4).
    static func handshake(at address: HostAddress, token: HostToken) -> URLRequest {
        var components = URLComponents(
            url: address.url(path: "v1/events"), resolvingAgainstBaseURL: false)
        components?.scheme = "ws"
        var request = URLRequest(url: components?.url ?? address.url(path: "v1/events"))
        request.setValue(HostRules.bearer(token), forHTTPHeaderField: "Authorization")
        return request
    }

    private static func bytes(of message: URLSessionWebSocketTask.Message) -> Data {
        switch message {
        case .data(let data): data
        case .string(let text): Data(text.utf8)
        @unknown default: Data()
        }
    }

    private static let policyViolation = 1008
    private static let forbidden = 403

    private static func end(of task: URLSessionWebSocketTask) -> EventsEnd {
        let status = (task.response as? HTTPURLResponse)?.statusCode
        if task.closeCode.rawValue == policyViolation || status == forbidden { return .refused }
        return .closed
    }
}

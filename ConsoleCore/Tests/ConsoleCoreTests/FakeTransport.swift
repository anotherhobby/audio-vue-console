import Foundation
import Testing

@testable import ConsoleCore

/// A transport that records each request and answers it by its method and path: a status, a body
/// and headers, or a thrown error. A request it has no answer for fails the test.
actor FakeTransport: HostTransport {
    enum Answer: Sendable {
        case status(Int, String, headers: [String: String] = [:])
        case failure(any Error)
    }

    /// A request's method and path, such as `GET /v1/version`.
    struct Route: Hashable, Sendable {
        let method: String
        let path: String

        init(_ method: String, _ path: String) {
            self.method = method
            self.path = path
        }

        static let version = Route("GET", "/v1/version")
        static let host = Route("GET", "/v1/host")
        static let ask = Route("POST", "/v1/pairing")
        static let confirm = Route("POST", "/v1/pairing/confirm")
        static let clients = Route("GET", "/v1/clients")
        static func revoke(_ id: String) -> Route { Route("DELETE", "/v1/clients/\(id)") }
    }

    private var answers: [Route: Answer]
    private(set) var requests: [URLRequest] = []

    init(_ answers: [Route: Answer]) {
        self.answers = answers
    }

    /// One answer to the version, the only request a connect to an unpaired host makes.
    init(_ answer: Answer) {
        self.init([.version: answer])
    }

    private static let ok = 200

    /// The host's answer when the panel is up, as the proving host gives it.
    static func version(_ api: String = "2.0.0", schema: String = "1") -> FakeTransport {
        FakeTransport([.version: versionAnswer(api, schema: schema)])
    }

    static func versionAnswer(_ api: String = "2.0.0", schema: String = "1") -> Answer {
        .status(ok, #"{"api": "\#(api)", "schema": \#(schema)}"#)
    }

    /// Sets or replaces the answer to a route, for a host that changes under the app.
    func answer(_ route: Route, with answer: Answer) {
        answers[route] = answer
    }

    /// The requests sent to a route, in order.
    func requests(to route: Route) -> [URLRequest] {
        requests.filter { Route($0.httpMethod ?? "", $0.url?.path() ?? "") == route }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let route = Route(request.httpMethod ?? "", request.url?.path() ?? "")
        guard let answer = answers[route] else {
            Issue.record("No answer for \(route.method) \(route.path)")
            throw URLError(.unsupportedURL)
        }
        switch answer {
        case .status(let code, let body, let headers):
            guard let url = request.url,
                let response = HTTPURLResponse(
                    url: url, statusCode: code, httpVersion: nil, headerFields: headers)
            else { throw URLError(.badURL) }
            return (Data(body.utf8), response)
        case .failure(let error):
            throw error
        }
    }
}

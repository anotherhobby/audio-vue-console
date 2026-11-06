import Foundation
import HTTPTypes
import HTTPTypesFoundation
import OpenAPIRuntime
import Testing

@testable import ConsoleCore

/// A transport under the generated client that records each request, as a `URLRequest` with its
/// body, and answers it by its method and path: a status, a body and headers, or a thrown error. A
/// request it has no answer for fails the test.
actor FakeTransport: ClientTransport {
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
    /// Answers for one host only, by its name, taken before `answers`.
    private var hostAnswers: [String: [Route: Answer]] = [:]
    private(set) var requests: [URLRequest] = []

    init(_ answers: [Route: Answer]) {
        self.answers = answers
    }

    /// One answer to the version, the only request a connect to an unpaired host makes.
    init(_ answer: Answer) {
        self.init([.version: answer])
    }

    private static let ok = 200

    /// API versions against the bundled contract's major, so no test names one it will outgrow.
    static let supportedAPI = "\(SavedContract.bundled.major).0.0"
    static let newerAPI = "\(SavedContract.bundled.major + 1).0.0"
    static let olderAPI = "\(SavedContract.bundled.major - 1).0.0"

    /// The host's answer when the panel is up, as the proving host gives it.
    static func version(_ api: String = supportedAPI, schema: String = "1") -> FakeTransport {
        FakeTransport([.version: versionAnswer(api, schema: schema)])
    }

    static func versionAnswer(_ api: String = supportedAPI, schema: String = "1") -> Answer {
        .status(ok, #"{"api": "\#(api)", "schema": \#(schema)}"#)
    }

    /// A request's JSON body as string fields, compared as JSON since the encoder picks its own
    /// spacing and key order.
    static func json(of request: URLRequest) -> [String: String]? {
        guard let body = request.httpBody else { return nil }
        do {
            return try JSONDecoder().decode([String: String].self, from: body)
        } catch {
            return nil
        }
    }

    /// Sets or replaces the answer to a route, for a host that changes under the app.
    func answer(_ route: Route, with answer: Answer) {
        answers[route] = answer
    }

    /// Sets or replaces the answer to a route at one host only, such as a remembered address that
    /// no longer answers.
    func answer(_ route: Route, at host: String, with answer: Answer) {
        hostAnswers[host, default: [:]][route] = answer
    }

    /// The requests sent to a route, in order.
    func requests(to route: Route) -> [URLRequest] {
        requests.filter { Route($0.httpMethod ?? "", $0.url?.path() ?? "") == route }
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String)
        async throws -> (HTTPResponse, HTTPBody?)
    {
        let recorded = try await Self.urlRequest(request, body: body, baseURL: baseURL)
        requests.append(recorded)
        let route = Route(request.method.rawValue, recorded.url?.path() ?? "")
        guard let answer = hostAnswers[baseURL.host() ?? ""]?[route] ?? answers[route] else {
            Issue.record("No answer for \(route.method) \(route.path)")
            throw URLError(.unsupportedURL)
        }
        switch answer {
        case .status(let code, let body, let headers):
            var fields = HTTPFields()
            for (name, value) in headers {
                guard let field = HTTPField.Name(name) else { throw URLError(.badServerResponse) }
                fields[field] = value
            }
            return (HTTPResponse(status: .init(code: code), headerFields: fields), HTTPBody(body))
        case .failure(let error):
            throw error
        }
    }

    /// The request as URLSession would have sent it, with its body read in.
    private static func urlRequest(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL)
        async throws -> URLRequest
    {
        var full = request
        full.scheme = baseURL.scheme
        full.authority = baseURL.host().map { host in baseURL.port.map { "\(host):\($0)" } ?? host }
        guard var recorded = URLRequest(httpRequest: full) else { throw URLError(.badURL) }
        if let body {
            recorded.httpBody = try await Data(collecting: body, upTo: .max)
        }
        return recorded
    }
}

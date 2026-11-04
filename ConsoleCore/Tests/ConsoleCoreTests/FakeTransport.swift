import Foundation

@testable import ConsoleCore

/// A transport that records each request and gives one canned answer: a status and body, or a
/// thrown error.
actor FakeTransport: HostTransport {
    enum Answer {
        case status(Int, String)
        case failure(any Error)
    }

    private let answer: Answer
    private(set) var requests: [URLRequest] = []

    init(_ answer: Answer) {
        self.answer = answer
    }

    private static let ok = 200

    /// The host's answer when the panel is up, as the proving host gives it.
    static func version(_ api: String = "1.0.0", schema: String = "1") -> FakeTransport {
        FakeTransport(.status(ok, #"{"api": "\#(api)", "schema": \#(schema)}"#))
    }

    func get(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        switch answer {
        case .status(let code, let body):
            guard let url = request.url,
                let response = HTTPURLResponse(
                    url: url, statusCode: code, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (Data(body.utf8), response)
        case .failure(let error):
            throw error
        }
    }
}

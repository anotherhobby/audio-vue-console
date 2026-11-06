import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import ConsoleCore

/// `host-client`, "Every call follows the host's rules in one place".
struct HostRulesTests {
    private static let open = "version_v1_version_get"
    private static let closed = "identity_v1_host_get"

    @Test func anOpenOperationCarriesNoTokenEvenWhenGivenOne() async throws {
        let sent = try await Self.sent(through: HostRules(token: HostToken("secret")), Self.open)
        #expect(sent.headerFields[.authorization] == nil)
    }

    @Test func aClosedOperationCarriesTheToken() async throws {
        let sent = try await Self.sent(through: HostRules(token: HostToken("secret")), Self.closed)
        #expect(sent.headerFields[.authorization] == "Bearer secret")
    }

    @Test func aClosedOperationWithNoTokenCarriesNone() async throws {
        let sent = try await Self.sent(through: HostRules(token: nil), Self.closed)
        #expect(sent.headerFields[.authorization] == nil)
    }

    @Test(arguments: [open, closed])
    func noRequestCarriesAnOrigin(operation: String) async throws {
        let sent = try await Self.sent(through: HostRules(token: HostToken("secret")), operation)
        #expect(sent.headerFields[.origin] == nil)
    }

    @Test func aRefusedTokenIsThrown() async {
        await #expect(throws: HostRules.TokenRefused.self) {
            _ = try await Self.sent(
                through: HostRules(token: HostToken("stale")), Self.closed, status: .unauthorized)
        }
    }

    @Test func aRefusalWithNoTokenIsTheCallersToRead() async throws {
        _ = try await Self.sent(through: HostRules(token: nil), Self.closed, status: .unauthorized)
    }

    /// What `rules` passes on for a request to `operation` that arrives carrying an `Origin`,
    /// answered with `status`.
    private static func sent(
        through rules: HostRules, _ operation: String, status: HTTPResponse.Status = .ok
    ) async throws -> HTTPRequest {
        var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/v1/x")
        request.headerFields[.origin] = "http://example.com"
        let seen = Seen()
        _ = try await rules.intercept(
            request, body: nil, baseURL: URL(fileURLWithPath: "/"), operationID: operation
        ) { passed, _, _ in
            await seen.record(passed)
            return (HTTPResponse(status: status), nil)
        }
        return try #require(await seen.request)
    }

    private actor Seen {
        var request: HTTPRequest?

        func record(_ request: HTTPRequest) {
            self.request = request
        }
    }
}

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// The host's rules, applied to every call in one place (`host-client`, "Every call follows the
/// host's rules in one place"; design D4): no request carries an `Origin` header, since the host
/// refuses any that does, and every operation the saved contract marks as taking a token carries
/// the call's token as `Authorization: Bearer`. A 401 to a request that carried the token is
/// `TokenRefused`, so no call has to check for it.
struct HostRules: ClientMiddleware {
    /// The host answered 401 to a request carrying the token.
    struct TokenRefused: Error {}

    /// The token the call was given, if any.
    let token: HostToken?
    /// The operations that take no token, from the saved contract.
    var openOperations = SavedContract.bundled.openOperations

    /// The `Authorization` value that carries `token`, for the events handshake as well.
    static func bearer(_ token: HostToken) -> String {
        "Bearer \(token.value)"
    }

    func intercept(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.origin] = nil
        let sent = openOperations.contains(operationID) ? nil : token
        if let sent {
            request.headerFields[.authorization] = Self.bearer(sent)
        }
        let (response, answer) = try await next(request, body, baseURL)
        if sent != nil, response.status == .unauthorized { throw TokenRefused() }
        return (response, answer)
    }
}

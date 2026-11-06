import Foundation

/// A client paired with a host, as its list gives it.
public struct PairedClient: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    /// When it paired, where the host's text reads as ISO 8601, as audio-vue writes it.
    public let pairedAt: Date?
    /// The host's text for when it paired, to show where it does not read as a date.
    public let pairedAtText: String

    public init(id: String, name: String, pairedAtText: String) {
        self.id = id
        self.name = name
        self.pairedAtText = pairedAtText
        pairedAt = Self.date(pairedAtText)
    }

    private static func date(_ text: String) -> Date? {
        do {
            return try Date(text, strategy: .iso8601)
        } catch {
            return nil
        }
    }
}

/// The host's paired clients: listing them and revoking one, both with a token.
extension HostClient {
    /// `GET /v1/clients`: every client paired with the host.
    public func clients(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> [PairedClient]
    {
        let output = try await call(at: address, token: token) {
            try await $0.clientsV1ClientsGet()
        }
        guard case .ok(let ok) = output else { throw .unexpectedAnswer }
        return try Self.body { try ok.body.json }.clients.map {
            PairedClient(id: $0.id, name: $0.name, pairedAtText: $0.pairedAt)
        }
    }

    /// `DELETE /v1/clients/{client_id}`: revokes a client, this app included, so its token is
    /// refused from then on.
    public func revoke(_ clientID: String, at address: HostAddress, token: HostToken)
        async throws(HostFailure)
    {
        let output = try await call(at: address, token: token) {
            try await $0.revokeV1ClientsClientIdDelete(path: .init(clientId: clientID))
        }
        switch output {
        case .noContent: return
        case .notFound: throw .unknownClient
        case .unauthorized, .unprocessableContent, .undocumented: throw .unexpectedAnswer
        }
    }
}

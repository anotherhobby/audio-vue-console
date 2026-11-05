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
        let (data, response) = try await send(.get, "v1/clients", at: address, token: token)
        guard response.statusCode == HTTPStatus.ok else { throw .unexpectedAnswer }
        return try Self.decode(ListedClients.self, from: data).clients.map {
            PairedClient(id: $0.id, name: $0.name, pairedAtText: $0.pairedAt)
        }
    }

    /// `DELETE /v1/clients/{client_id}`: revokes a client, this app included, so its token is
    /// refused from then on.
    public func revoke(_ clientID: String, at address: HostAddress, token: HostToken)
        async throws(HostFailure)
    {
        let (_, response) = try await send(
            .delete, "v1/clients/\(clientID)", at: address, token: token)
        switch response.statusCode {
        case HTTPStatus.noContent: return
        case HTTPStatus.notFound: throw .unknownClient
        default: throw .unexpectedAnswer
        }
    }
}

/// The body of `GET /v1/clients`.
private struct ListedClients: Decodable {
    struct Client: Decodable {
        let id: String
        let name: String
        let pairedAt: String

        enum CodingKeys: String, CodingKey {
            case id, name
            case pairedAt = "paired_at"
        }
    }

    let clients: [Client]
}

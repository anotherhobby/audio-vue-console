import Foundation
import HostAPI

/// What the host contract saved in this repository says about itself: the API's version, the one
/// this app supports, and the operations that take no token (`host-client`; design D3). The
/// saved contract is the only record of either.
public struct SavedContract: Sendable, Equatable {
    /// Why a contract could not be read.
    public enum Unreadable: Error, Sendable, Equatable {
        /// It is not JSON, or not an OpenAPI document with `info.version` and `paths`.
        case notAContract
        /// Its `info.version` is not semantic versioning.
        case versionNotSemantic(String)
    }

    /// The version of the API the contract describes.
    public let version: APIVersion
    /// The ids of the operations that declare no `security`, and so take no token.
    public let openOperations: Set<String>

    public init(version: APIVersion, openOperations: Set<String>) {
        self.version = version
        self.openOperations = openOperations
    }

    /// Reads an OpenAPI document's version and the operations without `security`.
    public init(json: Data) throws(Unreadable) {
        let document: Document
        do {
            document = try JSONDecoder().decode(Document.self, from: json)
        } catch {
            throw .notAContract
        }
        guard let version = APIVersion(parsing: document.info.version) else {
            throw .versionNotSemantic(document.info.version)
        }
        self.version = version
        openOperations = Set(
            document.paths.values.flatMap(\.operations).filter { $0.security == nil }.map(\.id))
    }

    /// The contract bundled with this build. It is part of the build, as a compiled-in value would
    /// be, so one that will not read is a defect of the build, not of any host: `SavedContractTests`
    /// fail on it, and the app stops rather than guess which API it speaks.
    public static let bundled: SavedContract = {
        do {
            guard let url = ContractFile.url else { throw Unreadable.notAContract }
            return try SavedContract(json: Data(contentsOf: url))
        } catch {
            fatalError("The bundled host contract could not be read: \(error)")
        }
    }()
}

/// The parts of an OpenAPI document `SavedContract` reads; the rest is ignored.
private struct Document: Decodable {
    struct Info: Decodable {
        let version: String
    }

    let info: Info
    let paths: [String: PathItem]
}

/// One path's operations, by the HTTP methods OpenAPI names; any other key of a path item is
/// ignored.
private struct PathItem: Decodable {
    struct Operation: Decodable {
        let id: String
        let security: [[String: [String]]]?

        enum CodingKeys: String, CodingKey {
            case id = "operationId"
            case security
        }
    }

    let operations: [Operation]

    private struct Method: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }

    private static let methods = [
        "get", "put", "post", "delete", "options", "head", "patch", "trace",
    ]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Method.self)
        operations = try Self.methods.compactMap {
            try container.decodeIfPresent(Operation.self, forKey: Method(stringValue: $0))
        }
    }
}

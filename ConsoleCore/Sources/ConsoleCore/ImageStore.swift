import Foundation

/// The host's backdrop images, kept in a directory of the app's own and named by id, where the
/// render helper reads them (`scene-rendering`, "Backdrop images are fetched before they are drawn").
public struct ImageStore: Sendable {
    public let directory: URL
    private let client: HostClient

    /// A store in `directory`, Application Support's `Images` by default, fetching through `client`.
    public init(
        directory: URL = URL.applicationSupportDirectory.appending(path: "Images"),
        client: HostClient = HostClient()
    ) {
        self.directory = directory
        self.client = client
    }

    /// Whether `id` has an image id's form, so it names a file in the store and nothing else: a
    /// name with no separator, ending in a format a backdrop reads, never `..` (audio-vue
    /// `images.FORM`).
    public static func isID(_ id: String) -> Bool {
        let form = /\w[\w.\-]*\.(?:png|jpg|jpeg)/.asciiOnlyWordCharacters()
        return !id.contains("..") && id.wholeMatch(of: form) != nil
    }

    /// Fetches `id` from the host unless the store holds it, answering whether it holds it after.
    /// An id of another form, or one the host does not have, is not held: the helper then draws the
    /// fallback and says the image is missing. An id once held is never fetched again, since an
    /// upload's id is its checksum and a shipped image's changes with it.
    public func fetch(_ id: String, at address: HostAddress, token: HostToken)
        async throws(HostFailure) -> Bool
    {
        guard Self.isID(id) else { return false }
        let file = directory.appending(path: id)
        if FileManager.default.fileExists(atPath: file.path) { return true }
        let bytes: Data
        do {
            bytes = try await client.image(id, at: address, token: token)
        } catch .notFound {
            return false
        }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try bytes.write(to: file, options: .atomic)
        } catch {
            throw .unexpectedAnswer
        }
        return true
    }
}

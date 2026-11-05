import Foundation

/// The app's token store: one `pairings.json` in a directory, readable by its owner only (design
/// D3). In the sandbox, Application Support is the app's container, which no update or rebuild
/// asks a password for, as the Keychain does (`pitfalls.md`).
public struct FileTokenStore: TokenStore {
    public static let fileName = "pairings.json"
    private static let ownerOnly: mode_t = 0o600

    public let directory: URL

    /// A store in `directory`, which need not exist until the first save makes it.
    public init(directory: URL) {
        self.directory = directory
    }

    /// The store in the app's Application Support.
    public static var applicationSupport: FileTokenStore {
        FileTokenStore(directory: .applicationSupportDirectory)
    }

    var file: URL { directory.appending(path: Self.fileName) }

    public func pairing(at address: HostAddress) -> Pairing? {
        read().pairing(at: address)
    }

    public func pairing(forHost hostID: String) -> Pairing? {
        read().pairing(forHost: hostID)
    }

    public func save(_ pairing: Pairing, at address: HostAddress) throws {
        var pairings = read()
        pairings.save(pairing, at: address)
        try write(pairings)
    }

    public func forget(host hostID: String) {
        var pairings = read()
        pairings.forget(host: hostID)
        do {
            try write(pairings)
        } catch {
            // Harmless, as `TokenStore.forget` says: the token kept is one the host refuses.
            return
        }
    }

    /// The file's pairings. A missing file is a store with none, and so is one that does not read,
    /// which the next save replaces.
    private func read() -> Pairings {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            return Pairings()
        }
        do {
            return try JSONDecoder().decode(Pairings.self, from: data)
        } catch {
            return Pairings()
        }
    }

    /// Writes a temporary file that is owner-only from the moment it exists, then moves it over the
    /// old one, so the file is never readable by others, nor ever half written.
    private func write(_ pairings: Pairings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(pairings)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appending(path: ".\(Self.fileName).\(UUID().uuidString)")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, Self.ownerOnly)
        guard descriptor >= 0 else { throw Self.lastError }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            // The umask can only take bits away from `open`'s mode; this sets it exactly.
            guard fchmod(descriptor, Self.ownerOnly) == 0 else { throw Self.lastError }
            try handle.write(contentsOf: data)
            try handle.close()
            guard rename(temporary.path, file.path) == 0 else { throw Self.lastError }
        } catch {
            unlink(temporary.path)
            throw error
        }
    }

    private static var lastError: POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}

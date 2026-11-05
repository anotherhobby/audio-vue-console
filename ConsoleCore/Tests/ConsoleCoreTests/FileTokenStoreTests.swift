import Foundation
import Testing

@testable import ConsoleCore

/// `host-pairing`, "The app keeps one token per host": the file the app keeps its tokens in.
struct FileTokenStoreTests {
    private let address = HostAddress(parsing: "audio-vue")
    private let pairing = Pairing(hostID: "h1", token: HostToken("secret"), clientID: "c1")

    /// A store in a fresh temporary directory that does not exist yet, removed afterwards.
    private func withStore(_ body: (FileTokenStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FileTokenStoreTests-\(UUID().uuidString)")
        defer { remove(directory) }
        try body(FileTokenStore(directory: directory))
    }

    private func remove(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record("Could not remove \(directory.path()): \(error)")
        }
    }

    private func mode(of store: FileTokenStore) throws -> Int? {
        try FileManager.default.attributesOfItem(atPath: store.file.path)[.posixPermissions]
            as? Int
    }

    @Test func aPairingSurvivesANewStore() throws {
        let address = try #require(address)
        try withStore { store in
            try store.save(pairing, at: address)
            let reopened = FileTokenStore(directory: store.directory)
            #expect(reopened.pairing(at: address) == pairing)
            #expect(reopened.pairing(forHost: "h1") == pairing)
        }
    }

    @Test func theFirstSaveMakesTheDirectory() throws {
        let address = try #require(address)
        try withStore { store in
            #expect(!FileManager.default.fileExists(atPath: store.directory.path()))
            #expect(store.pairing(at: address) == nil)
            try store.save(pairing, at: address)
            #expect(FileManager.default.fileExists(atPath: store.file.path()))
        }
    }

    @Test func theFileIsTheOwnersOnlyAfterEverySave() throws {
        let address = try #require(address)
        try withStore { store in
            try store.save(pairing, at: address)
            #expect(try mode(of: store) == 0o600)
            try store.save(
                Pairing(hostID: "h2", token: HostToken("other"), clientID: "c2"), at: address)
            #expect(try mode(of: store) == 0o600)
            store.forget(host: "h2")
            #expect(try mode(of: store) == 0o600)
        }
    }

    @Test func noTemporaryFileIsLeft() throws {
        let address = try #require(address)
        try withStore { store in
            try store.save(pairing, at: address)
            let names = try FileManager.default.contentsOfDirectory(atPath: store.directory.path())
            #expect(names == [FileTokenStore.fileName])
        }
    }

    @Test func forgettingIsKept() throws {
        let address = try #require(address)
        try withStore { store in
            try store.save(pairing, at: address)
            store.forget(host: "h1")
            #expect(FileTokenStore(directory: store.directory).pairing(at: address) == nil)
        }
    }

    @Test func aCorruptFileReadsAsEmptyAndIsReplaced() throws {
        let address = try #require(address)
        try withStore { store in
            try FileManager.default.createDirectory(
                at: store.directory, withIntermediateDirectories: true)
            try Data("not json".utf8).write(to: store.file)
            #expect(store.pairing(at: address) == nil)
            try store.save(pairing, at: address)
            #expect(FileTokenStore(directory: store.directory).pairing(at: address) == pairing)
        }
    }

    @Test func theFileHoldsHostsAndAddresses() throws {
        let address = try #require(address)
        try withStore { store in
            try store.save(pairing, at: address)
            let text = String(bytes: try Data(contentsOf: store.file), encoding: .utf8)
            #expect(
                text
                    == #"{"addresses":{"audio-vue":"h1"},"hosts":{"h1":{"client_id":"c1","token":"secret"}}}"#
            )
        }
    }
}

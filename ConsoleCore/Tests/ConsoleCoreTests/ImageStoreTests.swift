import Foundation
import Testing

@testable import ConsoleCore

/// `scene-rendering`, "Backdrop images are fetched before they are drawn".
struct ImageStoreTests {
    private let token = HostToken("secret")

    private func address() throws -> HostAddress {
        try #require(HostAddress(parsing: "audio-vue"))
    }

    private static func directory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    @Test(arguments: ["../x.png", "a/b.png", "sky.gif", ".png", "sky..png", "ünï.png"])
    func anIdOfAnotherFormIsRefused(id: String) {
        #expect(!ImageStore.isID(id))
    }

    @Test(arguments: ["sky.png", "aurora-01.jpeg", String(repeating: "ab", count: 32) + ".jpg"])
    func anIdOfTheForm(id: String) {
        #expect(ImageStore.isID(id))
    }

    @Test func anImageIsFetchedOnce() async throws {
        let transport = FakeTransport([
            .image("sky.png"): .status(200, "PNG", headers: ["Content-Type": "image/png"])
        ])
        let directory = Self.directory()
        let store = ImageStore(directory: directory, client: HostClient(transport: transport))
        #expect(try await store.fetch("sky.png", at: try address(), token: token))
        #expect(try await store.fetch("sky.png", at: try address(), token: token))
        #expect(await transport.requests.count == 1)
        #expect(try Data(contentsOf: directory.appending(path: "sky.png")) == Data("PNG".utf8))
    }

    @Test func anImageTheHostLacksIsNotHeld() async throws {
        let transport = FakeTransport([.image("gone.png"): .status(404, #"{"detail": "no"}"#)])
        let store = ImageStore(
            directory: Self.directory(), client: HostClient(transport: transport))
        #expect(try await !store.fetch("gone.png", at: try address(), token: token))
    }

    @Test func anIdOfAnotherFormIsNeverAsked() async throws {
        let transport = FakeTransport([:])
        let store = ImageStore(
            directory: Self.directory(), client: HostClient(transport: transport))
        #expect(try await !store.fetch("../etc/passwd.png", at: try address(), token: token))
        #expect(await transport.requests.isEmpty)
    }
}

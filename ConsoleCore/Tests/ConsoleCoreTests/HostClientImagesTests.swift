import Foundation
import Testing

@testable import ConsoleCore

/// `scene-settings`, "A backdrop image is chosen from the host or uploaded" (design D4).
struct HostClientImagesTests {
    private let token = HostToken("secret")

    private func address() throws -> HostAddress {
        try #require(HostAddress(parsing: "audio-vue"))
    }

    @Test func theListHoldsShippedAndUploadedImages() async throws {
        let body =
            #"{"images": [{"id": "a1.jpg", "shipped": false, "format": "jpeg", "bytes": 2048, "#
            + #""width": 3000, "height": 2000, "added_at": "2026-11-09T10:00:00+00:00"},"#
            + #"{"id": "b2.png", "shipped": false, "added_at": "2026-11-09T11:00:00+00:00"},"#
            + #"{"id": "aurora", "shipped": true}]}"#
        let transport = FakeTransport([.images: .status(200, body)])
        let images = try await HostClient(transport: transport).images(
            at: try address(), token: token)
        #expect(images.first?.width == 3000 && images.first?.bytes == 2048)
        #expect(images.first?.addedAt != nil)
        #expect(HostImage.listed(images).map(\.id) == ["aurora", "b2.png", "a1.jpg"])
    }

    @Test func anUploadSendsTheBytesAsTheirType() async throws {
        let transport = FakeTransport([.upload: .status(201, #"{"id": "c3.jpg"}"#)])
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let id = try await HostClient(transport: transport).upload(
            bytes, type: .jpeg, at: try address(), token: token)
        #expect(id == "c3.jpg")
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        #expect(request.httpBody == bytes)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func aRefusalSaysWhy() async throws {
        let transport = FakeTransport([
            .upload: .status(413, #"{"detail": "At most 16 MiB."}"#)
        ])
        await #expect(throws: HostFailure.imageRefused(.tooLarge("At most 16 MiB."))) {
            try await HostClient(transport: transport).upload(
                Data([1]), type: .png, at: try address(), token: token)
        }
        await transport.answer(.upload, with: .status(415, #"{"detail": "Not an image."}"#))
        await #expect(throws: HostFailure.imageRefused(.notPNGOrJPEG("Not an image."))) {
            try await HostClient(transport: transport).upload(
                Data([1]), type: .png, at: try address(), token: token)
        }
    }
}

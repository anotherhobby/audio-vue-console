import Foundation
import Testing

@testable import ConsoleCore

/// `host-client`, "Opening the events socket".
struct EventSourceTests {
    @Test func theHandshakeCarriesTheTokenAndNoOrigin() throws {
        let address = try #require(HostAddress(parsing: "audio-vue.local:8080"))
        let request = WebSocketEventSource.handshake(at: address, token: HostToken("secret"))
        #expect(request.url?.absoluteString == "ws://audio-vue.local:8080/v1/events")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }
}

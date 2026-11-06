import Testing

@testable import ConsoleCore

/// `host-connection`, "The user connects to a host by address".
struct HostAddressTests {
    @Test func anAddressWithoutAPortUsesTheAgentsDefault() throws {
        let address = try #require(HostAddress(parsing: "audio-vue.cabin.hobbysprawl.com"))
        #expect(
            address.url(path: "v1/version").absoluteString
                == "http://audio-vue.cabin.hobbysprawl.com:19200/v1/version")
    }

    @Test func anAddressWithAPortUsesIt() throws {
        let address = try #require(HostAddress(parsing: "192.168.1.20:8080"))
        #expect(
            address.url(path: "v1/version").absoluteString == "http://192.168.1.20:8080/v1/version")
    }

    @Test(arguments: [
        ("audio-vue", "audio-vue", 19200),
        ("  audio-vue.local \n", "audio-vue.local", 19200),
        ("10.0.0.1", "10.0.0.1", 19200),
        ("Audio-Vue:1", "Audio-Vue", 1),
        ("host:65535", "host", 65535),
        ("a1-b2.example", "a1-b2.example", 19200),
    ])
    func validAddresses(text: String, host: String, port: Int) throws {
        let address = try #require(HostAddress(parsing: text))
        #expect(address.host == host)
        #expect(address.port == port)
    }

    @Test(arguments: [
        "", "   ", "audio vue", "-audio.vue", "audio-.vue", "audio..vue", ".audio", "audio_vue",
        "http://audio-vue", "audio-vue/v1/version", "user@audio-vue", "999.1.1.1", "1.2.3",
        "1.2.3.4.5", "::1", "[::1]:19200", "audïo-vue", String(repeating: "a", count: 64) + ".com",
    ])
    func invalidHosts(text: String) {
        #expect(HostAddress(parsing: text) == nil)
    }

    @Test(arguments: [
        "host:0", "host:65536", "host:", "host:abc", "host:+80", "host:80:80", "host: 80",
    ])
    func invalidPorts(text: String) {
        #expect(HostAddress(parsing: text) == nil)
    }

    @Test func aHostnameOfTheMaximumLengthIsAccepted() {
        let label = String(repeating: "a", count: 63)
        let host = [label, label, label, String(repeating: "a", count: 61)].joined(separator: ".")
        #expect(host.count == 253)
        #expect(HostAddress(parsing: host) != nil)
        #expect(HostAddress(parsing: host + "a") == nil)
    }

    /// `host-discovery`, "A found panel is reached where it is announced".
    @Test func aResolvedHostTargetLosesItsTrailingDot() throws {
        let address = try #require(HostAddress(resolvedHost: "audio-vue.local.", port: 19200))
        #expect(address.description == "audio-vue.local")
        #expect(
            address.url(path: "v1/version").absoluteString
                == "http://audio-vue.local:19200/v1/version")
    }

    @Test func aResolvedPortIsKept() throws {
        let address = try #require(HostAddress(resolvedHost: "audio-vue.local.", port: 8080))
        #expect(address.port == 8080)
        #expect(address.description == "audio-vue.local:8080")
    }

    @Test(arguments: [
        ("audio_vue.local.", 19200), ("audio-vue.local..", 19200), ("", 19200),
        ("audio-vue.local.", 0),
    ])
    func aResolvedTargetThatIsNotAnAddressIsRefused(target: String, port: Int) {
        #expect(HostAddress(resolvedHost: target, port: port) == nil)
    }

    @Test func theDescriptionLeavesOutTheDefaultPort() throws {
        #expect(try #require(HostAddress(parsing: "audio-vue:19200")).description == "audio-vue")
        #expect(
            try #require(HostAddress(parsing: "audio-vue:8080")).description == "audio-vue:8080")
    }
}
